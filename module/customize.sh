#!/system/bin/sh

ui_print "*******************************"
ui_print "       F2FS Guardian v1        "
ui_print "          by Lolokeksu        "
ui_print "*******************************"

case ${API:-$(getprop ro.build.version.sdk 2>/dev/null)} in
    33|34|35|36) ;;
    *) abort "Android 13-16 (API 33-36) is required." ;;
esac

detect_data_fs() {
    DETECTED_FS=""

    # Prefer Android Toybox explicitly. KernelSU/KernelSU Next installers may
    # place BusyBox applets before system commands in PATH.
    if [ -x /system/bin/stat ]; then
        DETECTED_FS=$(/system/bin/stat -f -c '%T' /data 2>/dev/null)
    fi

    # Fall back to the stat implementation provided by the installer.
    if [ -z "$DETECTED_FS" ]; then
        DETECTED_FS=$(stat -f -c '%T' /data 2>/dev/null)
    fi

    # Read the actual mount table when stat is unavailable or incompatible.
    if [ -z "$DETECTED_FS" ] && [ -r /proc/self/mountinfo ]; then
        DETECTED_FS=$(
            awk '
                $5 == "/data" {
                    for (i = 1; i <= NF; i++) {
                        if ($i == "-") {
                            print $(i + 1)
                            exit
                        }
                    }
                }
            ' /proc/self/mountinfo 2>/dev/null
        )
    fi

    if [ -z "$DETECTED_FS" ] && [ -r /proc/mounts ]; then
        DETECTED_FS=$(
            awk '$2 == "/data" { print $3; exit }' /proc/mounts 2>/dev/null
        )
    fi

    # Normalize known representations returned by different stat builds.
    case "$DETECTED_FS" in
        f2fs|F2FS)
            DETECTED_FS=f2fs
            ;;
        0xf2f52010|f2f52010)
            DETECTED_FS=f2fs
            ;;
    esac

    printf '%s\n' "$DETECTED_FS"
}

FS=$(detect_data_fs)

case "$FS" in
    f2fs)
        ui_print "- Filesystem /data: F2FS"
        ;;
    ext4|erofs|btrfs|xfs|tmpfs)
        abort "/data must use F2FS; detected: $FS."
        ;;
    "")
        ui_print "! Unable to verify /data filesystem in installer context."
        ui_print "! Installation will continue with runtime verification."
        ;;
    *)
        ui_print "! Unrecognized /data filesystem result: $FS"
        ui_print "! Installation will continue with runtime verification."
        ;;
esac

OLD=/data/adb/modules/f2fs_guardian
DATA=/data/adb/f2fs_guardian
if [ -d "$OLD" ]; then
    mkdir -p "$DATA/state" 2>/dev/null
    touch "$DATA/state/stop_current" 2>/dev/null
    PID=$(cat "$DATA/state/daemon.lock/pid" 2>/dev/null)
    case $PID in ''|*[!0-9]*) ;; *) kill "$PID" 2>/dev/null ;; esac
    sleep 1
fi

mkdir -p "$DATA/state" "$DATA/logs" 2>/dev/null
chmod 0700 "$DATA" "$DATA/state" "$DATA/logs" 2>/dev/null
rm -rf "$DATA/state/daemon.lock" 2>/dev/null
rm -f "$DATA/state/manual_request" "$DATA/state/stop_current" "$DATA/state/owner_mode" \
      "$DATA/state/session_mode" "$DATA/state/session_started" 2>/dev/null
printf '%s\n' "installed; reboot required" > "$DATA/state/last_decision"
chmod 0600 "$DATA/state/last_decision" 2>/dev/null

set_perm "$MODPATH/f2fs-guardian.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/lib/common.sh" 0 0 0755
set_perm_recursive "$MODPATH/config" 0 0 0755 0644

ui_print "- Android API: ${API:-unknown}"
case "$FS" in
    f2fs) ;;
    *) ui_print "- Filesystem /data: deferred to post-boot self-test" ;;
esac
ui_print "- Persistent configuration is preserved"
ui_print "- Reboot, then run self-test"
