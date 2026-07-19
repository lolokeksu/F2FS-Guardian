#!/system/bin/sh

FG_MODDIR=${FG_MODDIR:-${MODDIR:-${0%/*}}}
FG_DATA_DIR=${FG_DATA_DIR:-/data/adb/f2fs_guardian}
FG_STATE_DIR=$FG_DATA_DIR/state
FG_LOG_DIR=$FG_DATA_DIR/logs
FG_LOG_FILE=$FG_LOG_DIR/guardian.log
FG_CONFIG_FILE=$FG_DATA_DIR/config.conf
FG_DEFAULT_CONFIG=$FG_MODDIR/config/default.conf

fg_now() {
    date +%s 2>/dev/null || echo 0
}

fg_is_uint() {
    case ${1-} in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

fg_read_int() {
    _fg_value=$(cat "$1" 2>/dev/null | tr -cd '0-9-' | head -c 20)
    case $_fg_value in
        ''|-) return 1 ;;
        *) printf '%s\n' "$_fg_value" ;;
    esac
}

fg_ensure_dirs() {
    mkdir -p "$FG_STATE_DIR" "$FG_LOG_DIR" 2>/dev/null
    chmod 0700 "$FG_DATA_DIR" "$FG_STATE_DIR" "$FG_LOG_DIR" 2>/dev/null
}

fg_state_write() {
    fg_ensure_dirs
    _fg_tmp=$FG_STATE_DIR/.tmp.$$
    printf '%s\n' "$2" > "$_fg_tmp" || return 1
    chmod 0600 "$_fg_tmp" 2>/dev/null
    mv -f "$_fg_tmp" "$FG_STATE_DIR/$1"
}

fg_state_read() {
    cat "$FG_STATE_DIR/$1" 2>/dev/null
}

fg_state_remove() {
    rm -f "$FG_STATE_DIR/$1" 2>/dev/null
}

fg_rotate_log() {
    [ -f "$FG_LOG_FILE" ] || return 0
    _fg_limit=${LOG_MAX_KB:-256}
    fg_is_uint "$_fg_limit" || _fg_limit=256
    _fg_size=$(wc -c < "$FG_LOG_FILE" 2>/dev/null)
    fg_is_uint "$_fg_size" || return 0
    [ "$_fg_size" -le $((_fg_limit * 1024)) ] && return 0
    tail -n 300 "$FG_LOG_FILE" > "$FG_LOG_FILE.tmp" 2>/dev/null && mv -f "$FG_LOG_FILE.tmp" "$FG_LOG_FILE"
}

fg_log() {
    fg_ensure_dirs
    fg_rotate_log
    _fg_ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
    [ -n "$_fg_ts" ] || _fg_ts=$(fg_now)
    printf '%s [%s] %s\n' "$_fg_ts" "$1" "$2" >> "$FG_LOG_FILE"
    chmod 0600 "$FG_LOG_FILE" 2>/dev/null
}

fg_set_default_config() {
    ENABLED=1
    AUTO_ENABLED=1
    CHECK_INTERVAL_MIN=60
    MIN_INTERVAL_HOURS=24
    MIN_SCREEN_OFF_MIN=20
    REQUIRE_CHARGING=1
    MIN_BATTERY_PERCENT=50
    MAX_BATTERY_TEMP_DECIC=390
    STORAGE_USAGE_TRIGGER_PERCENT=84
    DIRTY_SEGMENTS_TRIGGER=256
    CRITICAL_USAGE_PERCENT=95
    CRITICAL_DIRTY_SEGMENTS=128
    FREE_SEGMENTS_CRITICAL=96
    MAX_IO_OPS_PER_SEC=25
    IO_SAMPLE_SEC=5
    NORMAL_GC_MODE=2
    CRITICAL_GC_MODE=1
    NORMAL_DURATION_SEC=480
    CRITICAL_DURATION_SEC=90
    ACTIVE_RECHECK_SEC=15
    LOG_MAX_KB=256
}

fg_config_assign() {
    _fg_key=$1
    _fg_val=$2
    fg_is_uint "$_fg_val" || return 0
    case $_fg_key in
        ENABLED) [ "$_fg_val" -le 1 ] && ENABLED=$_fg_val ;;
        AUTO_ENABLED) [ "$_fg_val" -le 1 ] && AUTO_ENABLED=$_fg_val ;;
        CHECK_INTERVAL_MIN) [ "$_fg_val" -ge 1 ] && [ "$_fg_val" -le 1440 ] && CHECK_INTERVAL_MIN=$_fg_val ;;
        MIN_INTERVAL_HOURS) [ "$_fg_val" -le 720 ] && MIN_INTERVAL_HOURS=$_fg_val ;;
        MIN_SCREEN_OFF_MIN) [ "$_fg_val" -le 1440 ] && MIN_SCREEN_OFF_MIN=$_fg_val ;;
        REQUIRE_CHARGING) [ "$_fg_val" -le 1 ] && REQUIRE_CHARGING=$_fg_val ;;
        MIN_BATTERY_PERCENT) [ "$_fg_val" -le 100 ] && MIN_BATTERY_PERCENT=$_fg_val ;;
        MAX_BATTERY_TEMP_DECIC) [ "$_fg_val" -ge 250 ] && [ "$_fg_val" -le 600 ] && MAX_BATTERY_TEMP_DECIC=$_fg_val ;;
        STORAGE_USAGE_TRIGGER_PERCENT) [ "$_fg_val" -ge 1 ] && [ "$_fg_val" -le 100 ] && STORAGE_USAGE_TRIGGER_PERCENT=$_fg_val ;;
        DIRTY_SEGMENTS_TRIGGER) DIRTY_SEGMENTS_TRIGGER=$_fg_val ;;
        CRITICAL_USAGE_PERCENT) [ "$_fg_val" -ge 1 ] && [ "$_fg_val" -le 100 ] && CRITICAL_USAGE_PERCENT=$_fg_val ;;
        CRITICAL_DIRTY_SEGMENTS) CRITICAL_DIRTY_SEGMENTS=$_fg_val ;;
        FREE_SEGMENTS_CRITICAL) FREE_SEGMENTS_CRITICAL=$_fg_val ;;
        MAX_IO_OPS_PER_SEC) MAX_IO_OPS_PER_SEC=$_fg_val ;;
        IO_SAMPLE_SEC) [ "$_fg_val" -ge 1 ] && [ "$_fg_val" -le 30 ] && IO_SAMPLE_SEC=$_fg_val ;;
        NORMAL_GC_MODE) [ "$_fg_val" = 2 ] && NORMAL_GC_MODE=2 ;;
        CRITICAL_GC_MODE) [ "$_fg_val" = 1 ] && CRITICAL_GC_MODE=1 ;;
        NORMAL_DURATION_SEC) [ "$_fg_val" -ge 15 ] && [ "$_fg_val" -le 3600 ] && NORMAL_DURATION_SEC=$_fg_val ;;
        CRITICAL_DURATION_SEC) [ "$_fg_val" -ge 15 ] && [ "$_fg_val" -le 600 ] && CRITICAL_DURATION_SEC=$_fg_val ;;
        ACTIVE_RECHECK_SEC) [ "$_fg_val" -ge 5 ] && [ "$_fg_val" -le 300 ] && ACTIVE_RECHECK_SEC=$_fg_val ;;
        LOG_MAX_KB) [ "$_fg_val" -ge 32 ] && [ "$_fg_val" -le 4096 ] && LOG_MAX_KB=$_fg_val ;;
    esac
}

fg_parse_config_file() {
    [ -r "$1" ] || return 0
    while IFS= read -r _fg_line || [ -n "$_fg_line" ]; do
        _fg_line=${_fg_line%%#*}
        case $_fg_line in
            *=*)
                _fg_key=${_fg_line%%=*}
                _fg_val=${_fg_line#*=}
                _fg_key=$(printf '%s' "$_fg_key" | tr -d ' \t\r')
                _fg_val=$(printf '%s' "$_fg_val" | tr -d ' \t\r')
                fg_config_assign "$_fg_key" "$_fg_val"
                ;;
        esac
    done < "$1"
}

fg_load_config() {
    fg_set_default_config
    fg_parse_config_file "$FG_DEFAULT_CONFIG"
    fg_parse_config_file "$FG_CONFIG_FILE"
}

fg_install_default_config() {
    fg_ensure_dirs
    if [ ! -f "$FG_CONFIG_FILE" ]; then
        cp "$FG_DEFAULT_CONFIG" "$FG_CONFIG_FILE" 2>/dev/null || return 1
        chmod 0600 "$FG_CONFIG_FILE" 2>/dev/null
    fi
}

fg_config_set() {
    fg_load_config
    fg_config_assign "$1" "$2"
    _fg_tmp=$FG_CONFIG_FILE.tmp.$$
    cat > "$_fg_tmp" <<EOF_CONFIG
# F2FS Guardian v1
# Persistent user configuration. Integer values only.
ENABLED=$ENABLED
AUTO_ENABLED=$AUTO_ENABLED
CHECK_INTERVAL_MIN=$CHECK_INTERVAL_MIN
MIN_INTERVAL_HOURS=$MIN_INTERVAL_HOURS
MIN_SCREEN_OFF_MIN=$MIN_SCREEN_OFF_MIN
REQUIRE_CHARGING=$REQUIRE_CHARGING
MIN_BATTERY_PERCENT=$MIN_BATTERY_PERCENT
MAX_BATTERY_TEMP_DECIC=$MAX_BATTERY_TEMP_DECIC
STORAGE_USAGE_TRIGGER_PERCENT=$STORAGE_USAGE_TRIGGER_PERCENT
DIRTY_SEGMENTS_TRIGGER=$DIRTY_SEGMENTS_TRIGGER
CRITICAL_USAGE_PERCENT=$CRITICAL_USAGE_PERCENT
CRITICAL_DIRTY_SEGMENTS=$CRITICAL_DIRTY_SEGMENTS
FREE_SEGMENTS_CRITICAL=$FREE_SEGMENTS_CRITICAL
MAX_IO_OPS_PER_SEC=$MAX_IO_OPS_PER_SEC
IO_SAMPLE_SEC=$IO_SAMPLE_SEC
NORMAL_GC_MODE=$NORMAL_GC_MODE
CRITICAL_GC_MODE=$CRITICAL_GC_MODE
NORMAL_DURATION_SEC=$NORMAL_DURATION_SEC
CRITICAL_DURATION_SEC=$CRITICAL_DURATION_SEC
ACTIVE_RECHECK_SEC=$ACTIVE_RECHECK_SEC
LOG_MAX_KB=$LOG_MAX_KB
EOF_CONFIG
    chmod 0600 "$_fg_tmp" 2>/dev/null
    mv -f "$_fg_tmp" "$FG_CONFIG_FILE"
}

fg_root_manager() {
    if [ "${APATCH:-}" = true ] || [ "${KERNELPATCH:-}" = true ] || [ -d /data/adb/ap ] || [ -d /data/adb/apatch ]; then
        echo APatch
    elif [ "${KSU:-}" = true ] || [ -d /data/adb/ksu ]; then
        echo KernelSU
    elif [ -d /data/adb/magisk ] || command -v magisk >/dev/null 2>&1; then
        echo Magisk
    else
        echo Unknown
    fi
}

fg_android_api() {
    getprop ro.build.version.sdk 2>/dev/null | tr -cd '0-9'
}

fg_data_fs() {
    [ -n "${FG_DATA_FS:-}" ] && { echo "$FG_DATA_FS"; return; }
    stat -f -c %T /data 2>/dev/null || df -T /data 2>/dev/null | awk 'NR==2 {print $2}'
}

fg_data_source() {
    [ -n "${FG_DATA_SOURCE:-}" ] && { echo "$FG_DATA_SOURCE"; return; }
    if command -v findmnt >/dev/null 2>&1; then
        findmnt -n -o SOURCE /data 2>/dev/null && return 0
    fi
    mount 2>/dev/null | awk '$3=="/data" {print $1; exit}'
}

fg_instance_name() {
    _fg_source=$(fg_data_source)
    _fg_name=${_fg_source##*/}
    [ -n "$_fg_name" ] && [ -d "$FG_SYSFS_ROOT/$_fg_name" ] && { echo "$_fg_name"; return 0; }
    for _fg_dir in "$FG_SYSFS_ROOT"/*; do
        [ -d "$_fg_dir" ] || continue
        [ -r "$_fg_dir/gc_urgent" ] || continue
        basename "$_fg_dir"
        return 0
    done
    return 1
}

fg_init_runtime_paths() {
    FG_SYSFS_ROOT=${FG_SYSFS_ROOT:-/sys/fs/f2fs}
    FG_INSTANCE=${FG_INSTANCE:-$(fg_instance_name 2>/dev/null)}
    [ -n "$FG_INSTANCE" ] || return 1
    FG_INSTANCE_DIR=$FG_SYSFS_ROOT/$FG_INSTANCE
    FG_GC_FILE=$FG_INSTANCE_DIR/gc_urgent
    FG_FREE_FILE=$FG_INSTANCE_DIR/free_segments
    FG_DIRTY_FILE=$FG_INSTANCE_DIR/dirty_segments
    FG_BLOCK_STAT=${FG_BLOCK_STAT:-/sys/class/block/$FG_INSTANCE/stat}
    return 0
}

fg_storage_usage() {
    [ -n "${FG_STORAGE_USAGE:-}" ] && { echo "$FG_STORAGE_USAGE"; return; }
    df -P /data 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

fg_free_segments() {
    fg_read_int "$FG_FREE_FILE"
}

fg_dirty_segments() {
    fg_read_int "$FG_DIRTY_FILE"
}

fg_gc_mode() {
    fg_read_int "$FG_GC_FILE"
}

fg_write_gc_mode() {
    printf '%s\n' "$1" > "$FG_GC_FILE" 2>/dev/null
}

fg_battery_level() {
    [ -n "${FG_BATTERY_LEVEL:-}" ] && { echo "$FG_BATTERY_LEVEL"; return; }
    for _fg_file in /sys/class/power_supply/battery/capacity /sys/class/power_supply/Battery/capacity; do
        [ -r "$_fg_file" ] && { fg_read_int "$_fg_file"; return; }
    done
    dumpsys battery 2>/dev/null | awk -F: '/level:/ {gsub(/ /,"",$2); print $2; exit}'
}

fg_battery_temp() {
    [ -n "${FG_BATTERY_TEMP:-}" ] && { echo "$FG_BATTERY_TEMP"; return; }
    for _fg_file in /sys/class/power_supply/battery/temp /sys/class/power_supply/Battery/temp; do
        [ -r "$_fg_file" ] && { fg_read_int "$_fg_file"; return; }
    done
    dumpsys battery 2>/dev/null | awk -F: '/temperature:/ {gsub(/ /,"",$2); print $2; exit}'
}

fg_is_charging() {
    [ "${FG_CHARGING:-}" = 1 ] && return 0
    [ "${FG_CHARGING:-}" = 0 ] && return 1
    for _fg_file in /sys/class/power_supply/battery/status /sys/class/power_supply/Battery/status; do
        if [ -r "$_fg_file" ]; then
            _fg_status=$(cat "$_fg_file" 2>/dev/null)
            case $_fg_status in Charging|Full) return 0;; esac
        fi
    done
    for _fg_file in /sys/class/power_supply/*/online; do
        [ -r "$_fg_file" ] || continue
        [ "$(fg_read_int "$_fg_file" 2>/dev/null)" = 1 ] && return 0
    done
    return 1
}

fg_screen_is_on() {
    [ "${FG_SCREEN_ON:-}" = 1 ] && return 0
    [ "${FG_SCREEN_ON:-}" = 0 ] && return 1
    _fg_power=$(dumpsys power 2>/dev/null)
    printf '%s\n' "$_fg_power" | grep -Eq 'Display Power: state=ON|mWakefulness=Awake|mInteractive=true' && return 0
    printf '%s\n' "$_fg_power" | grep -Eq 'Display Power: state=OFF|mWakefulness=Asleep|mInteractive=false' && return 1
    dumpsys display 2>/dev/null | grep -Eq 'mScreenState=ON|mState=ON' && return 0
    return 1
}

fg_screen_off_minutes() {
    _fg_now=$(fg_now)
    if fg_screen_is_on; then
        fg_state_remove screen_off_since
        echo 0
        return
    fi
    _fg_since=$(fg_state_read screen_off_since)
    if ! fg_is_uint "$_fg_since"; then
        fg_state_write screen_off_since "$_fg_now"
        echo 0
        return
    fi
    [ "$_fg_now" -ge "$_fg_since" ] || { fg_state_write screen_off_since "$_fg_now"; echo 0; return; }
    echo $(((_fg_now - _fg_since) / 60))
}

fg_block_ops_total() {
    [ -r "$FG_BLOCK_STAT" ] || return 1
    awk '{print $1+$5}' "$FG_BLOCK_STAT" 2>/dev/null
}

fg_io_ops_per_sec() {
    [ -n "${FG_IO_OPS:-}" ] && { echo "$FG_IO_OPS"; return; }
    _fg_before=$(fg_block_ops_total) || return 1
    sleep "$IO_SAMPLE_SEC"
    _fg_after=$(fg_block_ops_total) || return 1
    [ "$_fg_after" -ge "$_fg_before" ] || return 1
    echo $(((_fg_after - _fg_before) / IO_SAMPLE_SEC))
}

fg_last_run_age_ok() {
    _fg_last=$(fg_state_read last_run_epoch)
    fg_is_uint "$_fg_last" || return 0
    _fg_now=$(fg_now)
    _fg_min=$((MIN_INTERVAL_HOURS * 3600))
    [ $((_fg_now - _fg_last)) -ge "$_fg_min" ]
}

fg_safety_reason() {
    _fg_screen=$(fg_screen_off_minutes)
    fg_is_uint "$_fg_screen" || _fg_screen=0
    [ "$_fg_screen" -ge "$MIN_SCREEN_OFF_MIN" ] || { echo "screen off ${_fg_screen}m < ${MIN_SCREEN_OFF_MIN}m"; return 1; }
    if [ "$REQUIRE_CHARGING" = 1 ] && ! fg_is_charging; then
        echo "not charging"
        return 1
    fi
    _fg_level=$(fg_battery_level)
    fg_is_uint "$_fg_level" || { echo "battery level unavailable"; return 1; }
    [ "$_fg_level" -ge "$MIN_BATTERY_PERCENT" ] || { echo "battery ${_fg_level}% < ${MIN_BATTERY_PERCENT}%"; return 1; }
    _fg_temp=$(fg_battery_temp)
    fg_is_uint "$_fg_temp" || { echo "battery temperature unavailable"; return 1; }
    [ "$_fg_temp" -le "$MAX_BATTERY_TEMP_DECIC" ] || { echo "battery temperature ${_fg_temp} > ${MAX_BATTERY_TEMP_DECIC} deci-C"; return 1; }
    if [ "${1:-full}" = full ]; then
        _fg_io=$(fg_io_ops_per_sec) || { echo "block I/O statistics unavailable"; return 1; }
        [ "$_fg_io" -le "$MAX_IO_OPS_PER_SEC" ] || { echo "I/O activity ${_fg_io} ops/s > ${MAX_IO_OPS_PER_SEC}"; return 1; }
    fi
    return 0
}
