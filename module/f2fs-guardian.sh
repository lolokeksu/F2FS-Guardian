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
  lang LANG    Set menu language: ru or en
  enable       Enable the daemon
  disable      Disable the daemon and stop module-owned work
  doctor       Show compatibility diagnostics
  self-test    Validate runtime prerequisites
  menu         Open the bilingual interactive terminal menu
  daemon       Internal late-start daemon

Short commands after reboot:
  f2g, f2status, f2check, f2request, f2cancel, f2logs
  f2doctor, f2start, f2stop, f2profile, f2lang
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

fg_current_profile() {
    fg_load_config
    if [ "$AUTO_ENABLED" = 0 ]; then
        echo manual
    elif [ "$CHECK_INTERVAL_MIN" = 120 ] && [ "$MIN_INTERVAL_HOURS" = 48 ] && \
         [ "$MIN_SCREEN_OFF_MIN" = 30 ] && [ "$STORAGE_USAGE_TRIGGER_PERCENT" = 88 ] && \
         [ "$DIRTY_SEGMENTS_TRIGGER" = 512 ]; then
        echo conservative
    elif [ "$CHECK_INTERVAL_MIN" = 60 ] && [ "$MIN_INTERVAL_HOURS" = 24 ] && \
         [ "$MIN_SCREEN_OFF_MIN" = 20 ] && [ "$STORAGE_USAGE_TRIGGER_PERCENT" = 84 ] && \
         [ "$DIRTY_SEGMENTS_TRIGGER" = 256 ]; then
        echo balanced
    else
        echo custom
    fi
}

fg_profile_label() {
    case "$1:$2" in
        balanced:ru) echo Сбалансированный ;;
        conservative:ru) echo Консервативный ;;
        manual:ru) echo Ручной ;;
        custom:ru) echo Пользовательский ;;
        balanced:*) echo Balanced ;;
        conservative:*) echo Conservative ;;
        manual:*) echo Manual ;;
        *) echo Custom ;;
    esac
}

fg_translate_decision() {
    _fg_text=$1
    _fg_lang=$2
    [ "$_fg_lang" = ru ] || { printf '%s
' "$_fg_text"; return; }
    case $_fg_text in
        'daemon disabled') echo 'демон отключён' ;;
        'runtime prerequisites unavailable') echo 'требования среды выполнения недоступны' ;;
        'statistics unavailable') echo 'статистика недоступна' ;;
        'not-yet-evaluated') echo 'ещё не проверялось' ;;
        'manual maintenance queued') echo 'ручное обслуживание поставлено в очередь' ;;
        'manual maintenance cancelled') echo 'ручное обслуживание отменено' ;;
        'active maintenance cancellation requested') echo 'запрошена отмена активного обслуживания' ;;
        'no trigger:'*) echo "триггер отсутствует:${_fg_text#*:}" ;;
        'normal trigger:'*) echo "обычный триггер:${_fg_text#*:}" ;;
        'critical trigger:'*) echo "критический триггер:${_fg_text#*:}" ;;
        'waiting:'*) echo "ожидание:${_fg_text#*:}" ;;
        'ready:'*) echo "готово:${_fg_text#*:}" ;;
        'maintenance active:'*) echo "обслуживание активно:${_fg_text#*:}" ;;
        'maintenance completed:'*) echo "обслуживание завершено:${_fg_text#*:}" ;;
        'maintenance stopped:'*) echo "обслуживание остановлено:${_fg_text#*:}" ;;
        *) printf '%s
' "$_fg_text" ;;
    esac
}

fg_collect_status() {
    fg_load_config
    fg_install_default_config >/dev/null 2>&1
    FG_ST_VERSION=$(fg_version)
    FG_ST_API=$(fg_android_api)
    FG_ST_FS=$(fg_data_fs); [ -n "$FG_ST_FS" ] || FG_ST_FS=unavailable
    FG_ST_FS_METHOD=$(fg_data_fs_method)
    FG_ST_DEVNUM=$(fg_data_devnum 2>/dev/null); [ -n "$FG_ST_DEVNUM" ] || FG_ST_DEVNUM=unavailable
    fg_init_runtime_paths >/dev/null 2>&1
    FG_ST_INSTANCE=${FG_INSTANCE:-unavailable}
    FG_ST_GC=$(fg_gc_mode 2>/dev/null); [ -n "$FG_ST_GC" ] || FG_ST_GC=unavailable
    FG_ST_FREE=$(fg_free_segments 2>/dev/null); [ -n "$FG_ST_FREE" ] || FG_ST_FREE=unavailable
    FG_ST_DIRTY=$(fg_dirty_segments 2>/dev/null); [ -n "$FG_ST_DIRTY" ] || FG_ST_DIRTY=unavailable
    FG_ST_USAGE=$(fg_storage_usage 2>/dev/null); [ -n "$FG_ST_USAGE" ] || FG_ST_USAGE=unavailable
    FG_ST_BATTERY=$(fg_battery_level 2>/dev/null); [ -n "$FG_ST_BATTERY" ] || FG_ST_BATTERY=unavailable
    FG_ST_TEMP=$(fg_battery_temp 2>/dev/null); [ -n "$FG_ST_TEMP" ] || FG_ST_TEMP=unavailable
    FG_ST_SCREEN=$(fg_screen_off_minutes 2>/dev/null); [ -n "$FG_ST_SCREEN" ] || FG_ST_SCREEN=unavailable
    if fg_is_charging; then FG_ST_CHARGING=yes; else FG_ST_CHARGING=no; fi
    if [ -f "$FG_STATE_DIR/manual_request" ]; then FG_ST_REQUEST=queued; else FG_ST_REQUEST=none; fi
    FG_ST_DECISION=$(fg_state_read last_decision); [ -n "$FG_ST_DECISION" ] || FG_ST_DECISION=not-yet-evaluated
    FG_ST_LAST_EPOCH=$(fg_state_read last_run_epoch)
    if fg_is_uint "$FG_ST_LAST_EPOCH"; then
        FG_ST_LAST_MODE=$(fg_state_read last_run_mode)
        FG_ST_LAST_DURATION=$(fg_state_read last_run_duration)
        FG_ST_LAST="epoch=$FG_ST_LAST_EPOCH mode=$FG_ST_LAST_MODE duration=${FG_ST_LAST_DURATION}s"
    else
        FG_ST_LAST=never
    fi
    FG_ST_PROFILE=$(fg_current_profile)
}

fg_status() {
    _fg_lang=${1:-en}
    fg_collect_status
    if [ "$_fg_lang" = ru ]; then
        _fg_charging=нет; [ "$FG_ST_CHARGING" = yes ] && _fg_charging=да
        _fg_request=нет; [ "$FG_ST_REQUEST" = queued ] && _fg_request=в_очереди
        _fg_last=$FG_ST_LAST; [ "$FG_ST_LAST" = never ] && _fg_last=никогда
        cat <<EOF_STATUS_RU
F2FS Guardian $FG_ST_VERSION
Root-менеджер: $(fg_root_manager)
Android API: ${FG_ST_API:-недоступно}
Файловая система /data: $FG_ST_FS
Метод определения: $FG_ST_FS_METHOD
Устройство /data: $FG_ST_DEVNUM
Экземпляр F2FS: $FG_ST_INSTANCE
gc_urgent: $FG_ST_GC
free_segments: $FG_ST_FREE
dirty_segments: $FG_ST_DIRTY
Заполнение накопителя: ${FG_ST_USAGE}%
Батарея: ${FG_ST_BATTERY}%
Температура батареи: $FG_ST_TEMP десятых °C
Экран выключен: $FG_ST_SCREEN мин
Зарядка: $_fg_charging
Демон включён: $ENABLED
Автоматическое обслуживание: $AUTO_ENABLED
Профиль: $(fg_profile_label "$FG_ST_PROFILE" ru)
Ручной запрос: $_fg_request
Последнее решение: $(fg_translate_decision "$FG_ST_DECISION" ru)
Последний запуск: $_fg_last
Журнал: $FG_LOG_FILE
EOF_STATUS_RU
    else
        cat <<EOF_STATUS
F2FS Guardian $FG_ST_VERSION
Root manager: $(fg_root_manager)
Android API: ${FG_ST_API:-unavailable}
Filesystem /data: $FG_ST_FS
Detection method: $FG_ST_FS_METHOD
/data device: $FG_ST_DEVNUM
F2FS instance: $FG_ST_INSTANCE
gc_urgent: $FG_ST_GC
free_segments: $FG_ST_FREE
dirty_segments: $FG_ST_DIRTY
Storage usage: ${FG_ST_USAGE}%
Battery: ${FG_ST_BATTERY}%
Battery temperature: $FG_ST_TEMP deci-C
Screen off: $FG_ST_SCREEN min
Charging: $FG_ST_CHARGING
Daemon enabled: $ENABLED
Automatic maintenance: $AUTO_ENABLED
Profile: $(fg_profile_label "$FG_ST_PROFILE" en)
Manual request: $FG_ST_REQUEST
Last decision: $FG_ST_DECISION
Last run: $FG_ST_LAST
Log: $FG_LOG_FILE
EOF_STATUS
    fi
}

fg_doctor() {
    _fg_lang=${1:-en}
    fg_load_config
    _fg_fs=$(fg_data_fs); [ -n "$_fg_fs" ] || _fg_fs=unavailable
    _fg_method=$(fg_data_fs_method)
    _fg_devnum=$(fg_data_devnum 2>/dev/null); [ -n "$_fg_devnum" ] || _fg_devnum=unavailable
    fg_init_runtime_paths >/dev/null 2>&1
    _fg_instance=${FG_INSTANCE:-unavailable}
    _fg_gc_read=no; _fg_gc_write=no; _fg_free=no; _fg_dirty=no; _fg_block=no
    [ -r "${FG_GC_FILE:-}" ] && _fg_gc_read=yes
    [ -w "${FG_GC_FILE:-}" ] && _fg_gc_write=yes
    [ -r "${FG_FREE_FILE:-}" ] && _fg_free=yes
    [ -r "${FG_DIRTY_FILE:-}" ] && _fg_dirty=yes
    [ -r "${FG_BLOCK_STAT:-}" ] && _fg_block=yes
    _fg_result=FAIL
    if [ "$_fg_fs" = f2fs ] && [ "$_fg_instance" != unavailable ] && \
       [ "$_fg_gc_read" = yes ] && [ "$_fg_gc_write" = yes ] && \
       [ "$_fg_free" = yes ] && [ "$_fg_dirty" = yes ] && [ "$_fg_block" = yes ]; then
        _fg_result=PASS
    fi
    if [ "$_fg_lang" = ru ]; then
        cat <<EOF_DOCTOR_RU
Диагностика F2FS Guardian
Root-менеджер: $(fg_root_manager)
Android API: $(fg_android_api)
Файловая система /data: $_fg_fs
Метод определения: $_fg_method
Номер устройства major:minor: $_fg_devnum
Экземпляр F2FS: $_fg_instance
gc_urgent чтение: $_fg_gc_read
gc_urgent запись: $_fg_gc_write
free_segments: $_fg_free
dirty_segments: $_fg_dirty
Статистика блочного устройства: $_fg_block
Результат: $_fg_result
EOF_DOCTOR_RU
    else
        cat <<EOF_DOCTOR
F2FS Guardian diagnostics
Root manager: $(fg_root_manager)
Android API: $(fg_android_api)
Filesystem /data: $_fg_fs
Detection method: $_fg_method
Device major:minor: $_fg_devnum
F2FS instance: $_fg_instance
gc_urgent readable: $_fg_gc_read
gc_urgent writable: $_fg_gc_write
free_segments: $_fg_free
dirty_segments: $_fg_dirty
Block-device statistics: $_fg_block
Result: $_fg_result
EOF_DOCTOR
    fi
    [ "$_fg_result" = PASS ]
}

fg_set_language() {
    case ${1:-} in
        ru|0) fg_config_set MENU_LANGUAGE 0; echo 'Язык меню: русский' ;;
        en|1) fg_config_set MENU_LANGUAGE 1; echo 'Menu language: English' ;;
        *) echo 'Usage: lang ru|en'; return 1 ;;
    esac
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

fg_menu_profile() {
    _fg_lang=$1
    while :; do
        if [ "$_fg_lang" = ru ]; then
            cat <<'EOF_PROFILE_RU'

Профили
1) Сбалансированный
2) Консервативный
3) Ручной
0) Назад
EOF_PROFILE_RU
            printf 'Выберите профиль: '
        else
            cat <<'EOF_PROFILE_EN'

Profiles
1) Balanced
2) Conservative
3) Manual
0) Back
EOF_PROFILE_EN
            printf 'Select profile: '
        fi
        if ! IFS= read -r _fg_profile_choice; then
            echo
            if [ "$_fg_lang" = ru ]; then
                echo 'Интерактивный ввод недоступен. Запустите меню командой f2g в Termux или ADB.'
            else
                echo 'Interactive input is unavailable. Run f2g from Termux or ADB.'
            fi
            return 2
        fi
        case $_fg_profile_choice in
            1) fg_apply_profile balanced >/dev/null; [ "$_fg_lang" = ru ] && echo 'Применён сбалансированный профиль.' || echo 'Balanced profile applied.'; return ;;
            2) fg_apply_profile conservative >/dev/null; [ "$_fg_lang" = ru ] && echo 'Применён консервативный профиль.' || echo 'Conservative profile applied.'; return ;;
            3) fg_apply_profile manual >/dev/null; [ "$_fg_lang" = ru ] && echo 'Применён ручной профиль.' || echo 'Manual profile applied.'; return ;;
            0) return ;;
            *) [ "$_fg_lang" = ru ] && echo 'Неверный выбор.' || echo 'Invalid selection.' ;;
        esac
    done
}

fg_menu() {
    while :; do
        fg_load_config
        _fg_lang=$(fg_resolve_menu_language)
        _fg_profile=$(fg_current_profile)
        _fg_fs=$(fg_data_fs); [ -n "$_fg_fs" ] || _fg_fs=unavailable
        fg_init_runtime_paths >/dev/null 2>&1
        _fg_instance=${FG_INSTANCE:-unavailable}
        _fg_decision=$(fg_state_read last_decision); [ -n "$_fg_decision" ] || _fg_decision=not-yet-evaluated
        if [ "$_fg_lang" = ru ]; then
            _fg_enabled=выключено; [ "$AUTO_ENABLED" = 1 ] && _fg_enabled=включено
            cat <<EOF_MENU_RU

================================
        F2FS Guardian $(fg_version)
================================

Профиль: $(fg_profile_label "$_fg_profile" ru)
Автоматическое обслуживание: $_fg_enabled
Состояние: $(fg_translate_decision "$_fg_decision" ru)
Файловая система: $_fg_fs
Экземпляр: $_fg_instance

1. Показать полный статус
2. Проверить условия запуска
3. Поставить обслуживание в очередь
4. Отменить обслуживание
5. Выбрать профиль
6. Включить автоматическое обслуживание
7. Отключить автоматическое обслуживание
8. Показать журнал
9. Запустить диагностику
10. English
0. Выход
EOF_MENU_RU
            printf 'Выберите действие: '
        else
            _fg_enabled=disabled; [ "$AUTO_ENABLED" = 1 ] && _fg_enabled=enabled
            cat <<EOF_MENU_EN

================================
        F2FS Guardian $(fg_version)
================================

Profile: $(fg_profile_label "$_fg_profile" en)
Automatic maintenance: $_fg_enabled
State: $_fg_decision
Filesystem: $_fg_fs
Instance: $_fg_instance

1. Show full status
2. Check maintenance conditions
3. Queue maintenance
4. Cancel maintenance
5. Select profile
6. Enable automatic maintenance
7. Disable automatic maintenance
8. Show log
9. Run diagnostics
10. Russian
0. Exit
EOF_MENU_EN
            printf 'Select an action: '
        fi
        if ! IFS= read -r _fg_choice; then
            echo
            if [ "$_fg_lang" = ru ]; then
                echo 'Интерактивный ввод недоступен. Запустите меню командой f2g в Termux или ADB.'
            else
                echo 'Interactive input is unavailable. Run f2g from Termux or ADB.'
            fi
            return 2
        fi
        echo
        case $_fg_choice in
            1) fg_status "$_fg_lang" ;;
            2)
                fg_evaluate 0 >/dev/null 2>&1
                fg_translate_decision "$FG_DECISION" "$_fg_lang"
                ;;
            3)
                fg_request >/dev/null
                [ "$_fg_lang" = ru ] && echo 'Безопасное обслуживание поставлено в очередь.' || echo 'Safe maintenance has been queued.'
                ;;
            4)
                fg_cancel >/dev/null
                [ "$_fg_lang" = ru ] && echo 'Запрос отмены обработан.' || echo 'Cancellation request processed.'
                ;;
            5) fg_menu_profile "$_fg_lang" ;;
            6)
                fg_config_set ENABLED 1
                fg_config_set AUTO_ENABLED 1
                [ "$_fg_lang" = ru ] && echo 'Автоматическое обслуживание включено.' || echo 'Automatic maintenance enabled.'
                ;;
            7)
                fg_config_set AUTO_ENABLED 0
                fg_cancel >/dev/null
                fg_stop_owned_mode
                [ "$_fg_lang" = ru ] && echo 'Автоматическое обслуживание отключено.' || echo 'Automatic maintenance disabled.'
                ;;
            8) tail -n 100 "$FG_LOG_FILE" 2>/dev/null ;;
            9) fg_doctor "$_fg_lang" ;;
            10)
                if [ "$_fg_lang" = ru ]; then fg_config_set MENU_LANGUAGE 1; else fg_config_set MENU_LANGUAGE 0; fi
                ;;
            0) return 0 ;;
            *) [ "$_fg_lang" = ru ] && echo 'Неверный выбор.' || echo 'Invalid selection.' ;;
        esac
    done
}

fg_ensure_dirs
fg_install_default_config >/dev/null 2>&1

case ${1:-status} in
    status) fg_status en ;;
    status-ui) fg_load_config; fg_status "$(fg_resolve_menu_language)" ;;
    check) fg_check ;;
    check-ui) fg_load_config; fg_evaluate 0 >/dev/null 2>&1; fg_translate_decision "$FG_DECISION" "$(fg_resolve_menu_language)" ;;
    request) fg_request ;;
    cancel) fg_cancel ;;
    logs) tail -n 100 "$FG_LOG_FILE" 2>/dev/null ;;
    config) cat "$FG_CONFIG_FILE" ;;
    profile) fg_apply_profile "${2:-}" ;;
    lang) fg_set_language "${2:-}" ;;
    enable) fg_config_set ENABLED 1; fg_config_set AUTO_ENABLED 1; echo "Daemon enabled." ;;
    disable) fg_config_set AUTO_ENABLED 0; fg_cancel >/dev/null; fg_stop_owned_mode; echo "Automatic maintenance disabled." ;;
    doctor) fg_doctor en ;;
    doctor-ui) fg_load_config; fg_doctor "$(fg_resolve_menu_language)" ;;
    self-test) fg_prerequisites && echo "PASS: runtime prerequisites are available" ;;
    menu) fg_menu ;;
    daemon) fg_daemon ;;
    once) fg_evaluate 1 ;;
    help|-h|--help) fg_usage ;;
    *) fg_usage; exit 1 ;;
esac
