#!/system/bin/sh

MODDIR=${FG_MODDIR:-${0%/*}}
FG_MODDIR=$MODDIR
# shellcheck source=lib/common.sh
. "$MODDIR/lib/common.sh"

fg_version() {
    sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null | head -n 1
}

fg_usage() {
    cat <<'EOF_USAGE'
F2FS Guardian commands:
  status       Show filesystem, device and daemon state
  check        Evaluate trigger and safety conditions without starting GC
  request      Queue a bounded maintenance session
  cancel       Cancel a queued or active module-owned session
  logs         Show recent log entries
  config       Show persistent configuration
  profile NAME Apply balanced, conservative or manual profile
  enable       Enable the daemon
  disable      Disable the daemon and stop module-owned work
  self-test    Validate runtime prerequisites
  menu         Open the interactive terminal menu
  daemon       Internal late-start daemon
EOF_USAGE
}

fg_prerequisites() {
    fg_load_config
    [ "$(fg_data_fs)" = f2fs ] || { echo "FAIL: /data is not F2FS"; return 1; }
    fg_init_runtime_paths || { echo "FAIL: no F2FS instance for /data"; return 1; }
    [ -r "$FG_GC_FILE" ] && [ -w "$FG_GC_FILE" ] || { echo "FAIL: gc_urgent is not readable and writable"; return 1; }
    [ -r "$FG_FREE_FILE" ] || { echo "FAIL: free_segments is unavailable"; return 1; }
    [ -r "$FG_DIRTY_FILE" ] || { echo "FAIL: dirty_segments is unavailable"; return 1; }
    [ -r "$FG_BLOCK_STAT" ] || { echo "FAIL: block-device statistics are unavailable"; return 1; }
    command -v awk >/dev/null 2>&1 || { echo "FAIL: awk is unavailable"; return 1; }
    command -v df >/dev/null 2>&1 || { echo "FAIL: df is unavailable"; return 1; }
    return 0
}

fg_decide_trigger() {
    _fg_usage=$(fg_storage_usage)
    _fg_dirty=$(fg_dirty_segments)
    _fg_free=$(fg_free_segments)
    fg_is_uint "$_fg_usage" && fg_is_uint "$_fg_dirty" && fg_is_uint "$_fg_free" || {
        FG_DECISION="statistics unavailable"
        FG_SELECTED_MODE=0
        FG_SELECTED_DURATION=0
        return 1
    }
    FG_SNAPSHOT="usage=$_fg_usage dirty=$_fg_dirty free=$_fg_free"
    if [ "$_fg_usage" -ge "$CRITICAL_USAGE_PERCENT" ] && \
       [ "$_fg_dirty" -ge "$CRITICAL_DIRTY_SEGMENTS" ] && \
       [ "$_fg_free" -le "$FREE_SEGMENTS_CRITICAL" ]; then
        FG_DECISION="critical trigger: $FG_SNAPSHOT"
        FG_SELECTED_MODE=$CRITICAL_GC_MODE
        FG_SELECTED_DURATION=$CRITICAL_DURATION_SEC
        return 0
    fi
    if [ "$_fg_usage" -ge "$STORAGE_USAGE_TRIGGER_PERCENT" ] && \
       [ "$_fg_dirty" -ge "$DIRTY_SEGMENTS_TRIGGER" ]; then
        FG_DECISION="normal trigger: $FG_SNAPSHOT"
        FG_SELECTED_MODE=$NORMAL_GC_MODE
        FG_SELECTED_DURATION=$NORMAL_DURATION_SEC
        return 0
    fi
    FG_DECISION="no trigger: $FG_SNAPSHOT"
    FG_SELECTED_MODE=0
    FG_SELECTED_DURATION=0
    return 1
}

fg_owned_mode() {
    fg_state_read owner_mode
}

fg_stop_owned_mode() {
    fg_init_runtime_paths || return 0
    _fg_owned=$(fg_owned_mode)
    fg_is_uint "$_fg_owned" || return 0
    _fg_current=$(fg_gc_mode)
    if [ "$_fg_current" = "$_fg_owned" ]; then
        if fg_write_gc_mode 0 && [ "$(fg_gc_mode)" = 0 ]; then
            fg_log INFO "restored module-owned gc_urgent=$_fg_owned to 0"
        else
            fg_log ERROR "failed to restore module-owned gc_urgent=$_fg_owned"
        fi
    elif [ -n "$_fg_current" ]; then
        fg_log WARN "ownership lost during stop: owned=$_fg_owned current=$_fg_current"
    fi
    fg_state_remove owner_mode
    fg_state_remove session_mode
    fg_state_remove session_started
}

fg_active_safety_ok() {
    _fg_reason=$(fg_safety_reason active)
    if [ $? -ne 0 ]; then
        FG_ACTIVE_STOP_REASON="safety changed: $_fg_reason"
        return 1
    fi
    return 0
}

fg_run_session() {
    _fg_mode=$1
    _fg_duration=$2
    _fg_origin=$3
    fg_init_runtime_paths || return 1
    _fg_current=$(fg_gc_mode)
    if [ "$_fg_current" != 0 ]; then
        fg_state_write last_decision "conflict: gc_urgent already $_fg_current"
        fg_log WARN "session refused: gc_urgent=$_fg_current is already active"
        return 1
    fi
    fg_state_remove stop_current
    if ! fg_write_gc_mode "$_fg_mode" || [ "$(fg_gc_mode)" != "$_fg_mode" ]; then
        fg_state_write last_decision "failed to activate gc_urgent=$_fg_mode"
        fg_log ERROR "kernel rejected gc_urgent=$_fg_mode"
        return 1
    fi
    _fg_start=$(fg_now)
    fg_state_write owner_mode "$_fg_mode"
    fg_state_write session_mode "$_fg_mode"
    fg_state_write session_started "$_fg_start"
    fg_state_write last_decision "maintenance active: origin=$_fg_origin mode=$_fg_mode"
    fg_log INFO "maintenance started; origin=$_fg_origin mode=$_fg_mode duration=${_fg_duration}s"

    _fg_elapsed=0
    _fg_result=completed
    while [ "$_fg_elapsed" -lt "$_fg_duration" ]; do
        sleep "$ACTIVE_RECHECK_SEC"
        _fg_elapsed=$((_fg_elapsed + ACTIVE_RECHECK_SEC))
        if [ -f "$FG_STATE_DIR/stop_current" ]; then
            _fg_result=cancelled
            break
        fi
        _fg_current=$(fg_gc_mode)
        if [ "$_fg_current" != "$_fg_mode" ]; then
            _fg_result="ownership-lost(current=$_fg_current)"
            fg_state_remove owner_mode
            break
        fi
        if ! fg_active_safety_ok; then
            _fg_result=$FG_ACTIVE_STOP_REASON
            break
        fi
    done

    _fg_end=$(fg_now)
    _fg_actual=$((_fg_end - _fg_start))
    [ "$_fg_actual" -ge 0 ] 2>/dev/null || _fg_actual=$_fg_elapsed
    _fg_owned=$(fg_owned_mode)
    _fg_current=$(fg_gc_mode)
    if [ "$_fg_owned" = "$_fg_mode" ] && [ "$_fg_current" = "$_fg_mode" ]; then
        fg_write_gc_mode 0
    fi
    fg_state_remove owner_mode
    fg_state_remove session_mode
    fg_state_remove session_started
    fg_state_remove stop_current

    if [ "$_fg_result" = completed ]; then
        fg_state_write last_run_epoch "$_fg_end"
        fg_state_write last_run_mode "$_fg_mode"
        fg_state_write last_run_duration "$_fg_actual"
        fg_state_write last_decision "maintenance completed: mode=$_fg_mode duration=${_fg_actual}s"
        rm -f "$FG_STATE_DIR/manual_request" 2>/dev/null
        fg_log INFO "maintenance completed; mode=$_fg_mode duration=${_fg_actual}s"
        return 0
    fi
    fg_state_write last_decision "maintenance stopped: $_fg_result"
    fg_log WARN "maintenance stopped; mode=$_fg_mode reason=$_fg_result duration=${_fg_actual}s"
    return 1
}

fg_evaluate() {
    _fg_allow_start=${1:-0}
    fg_load_config
    fg_install_default_config >/dev/null 2>&1
    if [ "$ENABLED" != 1 ]; then
        FG_DECISION="daemon disabled"
        fg_state_write last_decision "$FG_DECISION"
        return 1
    fi
    if ! fg_prerequisites >/dev/null; then
        FG_DECISION="runtime prerequisites unavailable"
        fg_state_write last_decision "$FG_DECISION"
        return 1
    fi
    fg_decide_trigger
    _fg_auto_triggered=0
    [ "$FG_SELECTED_MODE" -ne 0 ] && _fg_auto_triggered=1
    _fg_manual=0
    [ -f "$FG_STATE_DIR/manual_request" ] && _fg_manual=1

    if [ "$_fg_manual" = 1 ]; then
        FG_SELECTED_MODE=$NORMAL_GC_MODE
        FG_SELECTED_DURATION=$NORMAL_DURATION_SEC
        FG_DECISION="manual maintenance queued"
        _fg_origin=manual
    elif [ "$AUTO_ENABLED" = 1 ] && [ "$_fg_auto_triggered" = 1 ]; then
        _fg_origin=automatic
    else
        fg_state_write last_decision "$FG_DECISION"
        return 1
    fi

    if ! fg_last_run_age_ok; then
        FG_DECISION="waiting: minimum interval has not elapsed"
        fg_state_write last_decision "$FG_DECISION"
        return 1
    fi
    _fg_reason=$(fg_safety_reason full)
    if [ $? -ne 0 ]; then
        FG_DECISION="waiting: $_fg_reason"
        fg_state_write last_decision "$FG_DECISION"
        return 1
    fi
    FG_DECISION="ready: origin=$_fg_origin mode=$FG_SELECTED_MODE duration=${FG_SELECTED_DURATION}s"
    fg_state_write last_decision "$FG_DECISION"
    [ "$_fg_allow_start" = 1 ] || return 0
    fg_run_session "$FG_SELECTED_MODE" "$FG_SELECTED_DURATION" "$_fg_origin"
}

fg_daemon_lock() {
    _fg_lock=$FG_STATE_DIR/daemon.lock
    if mkdir "$_fg_lock" 2>/dev/null; then
        printf '%s\n' $$ > "$_fg_lock/pid"
        return 0
    fi
    _fg_pid=$(cat "$_fg_lock/pid" 2>/dev/null)
    if fg_is_uint "$_fg_pid" && kill -0 "$_fg_pid" 2>/dev/null; then
        return 1
    fi
    rm -rf "$_fg_lock" 2>/dev/null
    mkdir "$_fg_lock" 2>/dev/null || return 1
    printf '%s\n' $$ > "$_fg_lock/pid"
}

fg_daemon_cleanup() {
    fg_stop_owned_mode
    rm -rf "$FG_STATE_DIR/daemon.lock" 2>/dev/null
}

fg_daemon() {
    fg_ensure_dirs
    fg_install_default_config || exit 1
    fg_daemon_lock || exit 0
    trap 'fg_daemon_cleanup; exit 0' INT TERM HUP EXIT
    fg_load_config
    fg_log INFO "daemon starting; root=$(fg_root_manager)"
    _fg_next_auto=0
    while :; do
        fg_load_config
        fg_state_write heartbeat_epoch "$(fg_now)"
        if [ -f "$MODDIR/disable" ] || [ "$ENABLED" != 1 ]; then
            fg_stop_owned_mode
            sleep 60
            continue
        fi
        _fg_now=$(fg_now)
        _fg_manual=0
        [ -f "$FG_STATE_DIR/manual_request" ] && _fg_manual=1
        if [ "$_fg_manual" = 1 ] || [ "$_fg_now" -ge "$_fg_next_auto" ]; then
            fg_state_write last_check_epoch "$_fg_now"
            fg_evaluate 1
            _fg_next_auto=$((_fg_now + CHECK_INTERVAL_MIN * 60))
        fi
        sleep 60
    done
}

fg_status() {
    fg_load_config
    fg_install_default_config >/dev/null 2>&1
    _fg_version=$(fg_version)
    _fg_api=$(fg_android_api)
    _fg_fs=$(fg_data_fs)
    fg_init_runtime_paths >/dev/null 2>&1
    _fg_instance=${FG_INSTANCE:-unavailable}
    _fg_gc=$(fg_gc_mode 2>/dev/null); [ -n "$_fg_gc" ] || _fg_gc=unavailable
    _fg_free=$(fg_free_segments 2>/dev/null); [ -n "$_fg_free" ] || _fg_free=unavailable
    _fg_dirty=$(fg_dirty_segments 2>/dev/null); [ -n "$_fg_dirty" ] || _fg_dirty=unavailable
    _fg_usage=$(fg_storage_usage 2>/dev/null); [ -n "$_fg_usage" ] || _fg_usage=unavailable
    _fg_battery=$(fg_battery_level 2>/dev/null); [ -n "$_fg_battery" ] || _fg_battery=unavailable
    _fg_temp=$(fg_battery_temp 2>/dev/null); [ -n "$_fg_temp" ] || _fg_temp=unavailable
    _fg_screen=$(fg_screen_off_minutes 2>/dev/null); [ -n "$_fg_screen" ] || _fg_screen=unavailable
    if fg_is_charging; then _fg_charging=yes; else _fg_charging=no; fi
    if [ -f "$FG_STATE_DIR/manual_request" ]; then _fg_request=queued; else _fg_request=none; fi
    _fg_decision=$(fg_state_read last_decision); [ -n "$_fg_decision" ] || _fg_decision=not-yet-evaluated
    _fg_last_epoch=$(fg_state_read last_run_epoch)
    if fg_is_uint "$_fg_last_epoch"; then
        _fg_last_mode=$(fg_state_read last_run_mode)
        _fg_last_duration=$(fg_state_read last_run_duration)
        _fg_last="epoch=$_fg_last_epoch mode=$_fg_last_mode duration=${_fg_last_duration}s"
    else
        _fg_last=never
    fi
    cat <<EOF_STATUS
F2FS Guardian $_fg_version
Root manager: $(fg_root_manager)
Android API: ${_fg_api:-unavailable}
Filesystem /data: ${_fg_fs:-unavailable}
F2FS instance: $_fg_instance
gc_urgent: $_fg_gc
free_segments: $_fg_free
dirty_segments: $_fg_dirty
Storage usage: ${_fg_usage}%
Battery: ${_fg_battery}%
Battery temperature: $_fg_temp deci-C
Screen off: $_fg_screen min
Charging: $_fg_charging
Daemon enabled: $ENABLED
Automatic maintenance: $AUTO_ENABLED
Manual request: $_fg_request
Last decision: $_fg_decision
Last run: $_fg_last
Log: $FG_LOG_FILE
EOF_STATUS
}

fg_request() {
    fg_ensure_dirs
    : > "$FG_STATE_DIR/manual_request"
    chmod 0600 "$FG_STATE_DIR/manual_request" 2>/dev/null
    fg_state_write last_decision "manual maintenance queued"
    echo "Safe maintenance has been queued."
    echo "It will start only after all safety conditions are satisfied."
}

fg_cancel() {
    fg_ensure_dirs
    if [ -f "$FG_STATE_DIR/owner_mode" ] || [ -f "$FG_STATE_DIR/session_mode" ]; then
        : > "$FG_STATE_DIR/stop_current"
        rm -f "$FG_STATE_DIR/manual_request" 2>/dev/null
        fg_state_write last_decision "active maintenance cancellation requested"
        echo "Active module-owned maintenance cancellation requested."
    else
        rm -f "$FG_STATE_DIR/manual_request" "$FG_STATE_DIR/stop_current" 2>/dev/null
        fg_state_write last_decision "manual maintenance cancelled"
        echo "Queued maintenance has been cancelled."
    fi
}

fg_check() {
    if fg_evaluate 0; then
        echo "$FG_DECISION"
        return 0
    fi
    echo "$FG_DECISION"
    return 1
}

fg_apply_profile() {
    case ${1:-} in
        balanced)
            fg_config_set ENABLED 1
            fg_config_set AUTO_ENABLED 1
            fg_config_set CHECK_INTERVAL_MIN 60
            fg_config_set MIN_INTERVAL_HOURS 24
            fg_config_set MIN_SCREEN_OFF_MIN 20
            fg_config_set STORAGE_USAGE_TRIGGER_PERCENT 84
            fg_config_set DIRTY_SEGMENTS_TRIGGER 256
            fg_config_set NORMAL_DURATION_SEC 480
            fg_config_set CRITICAL_DURATION_SEC 90
            ;;
        conservative)
            fg_config_set ENABLED 1
            fg_config_set AUTO_ENABLED 1
            fg_config_set CHECK_INTERVAL_MIN 120
            fg_config_set MIN_INTERVAL_HOURS 48
            fg_config_set MIN_SCREEN_OFF_MIN 30
            fg_config_set STORAGE_USAGE_TRIGGER_PERCENT 88
            fg_config_set DIRTY_SEGMENTS_TRIGGER 512
            fg_config_set NORMAL_DURATION_SEC 300
            fg_config_set CRITICAL_DURATION_SEC 60
            ;;
        manual)
            fg_config_set ENABLED 1
            fg_config_set AUTO_ENABLED 0
            ;;
        *) echo "Unknown profile: ${1:-}"; return 1 ;;
    esac
    echo "Profile applied: $1"
}

fg_menu() {
    while :; do
        cat <<'EOF_MENU'

F2FS Guardian
1) Status
2) Check conditions
3) Queue maintenance
4) Cancel maintenance
5) Show logs
6) Balanced profile
7) Conservative profile
8) Manual profile
0) Exit
EOF_MENU
        printf 'Select: '
        IFS= read -r _fg_choice
        case $_fg_choice in
            1) fg_status ;;
            2) fg_check ;;
            3) fg_request ;;
            4) fg_cancel ;;
            5) tail -n 100 "$FG_LOG_FILE" 2>/dev/null ;;
            6) fg_apply_profile balanced ;;
            7) fg_apply_profile conservative ;;
            8) fg_apply_profile manual ;;
            0) return 0 ;;
            *) echo "Invalid selection" ;;
        esac
    done
}

fg_ensure_dirs
fg_install_default_config >/dev/null 2>&1

case ${1:-status} in
    status) fg_status ;;
    check) fg_check ;;
    request) fg_request ;;
    cancel) fg_cancel ;;
    logs) tail -n 100 "$FG_LOG_FILE" 2>/dev/null ;;
    config) cat "$FG_CONFIG_FILE" ;;
    profile) fg_apply_profile "${2:-}" ;;
    enable) fg_config_set ENABLED 1; echo "Daemon enabled." ;;
    disable) fg_config_set ENABLED 0; fg_cancel >/dev/null; fg_stop_owned_mode; echo "Daemon disabled." ;;
    self-test) fg_prerequisites && echo "PASS: runtime prerequisites are available" ;;
    menu) fg_menu ;;
    daemon) fg_daemon ;;
    once) fg_evaluate 1 ;;
    help|-h|--help) fg_usage ;;
    *) fg_usage; exit 1 ;;
esac
