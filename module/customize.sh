#!/system/bin/sh

ui_print "*******************************"
ui_print "       F2FS Guardian v1        "
ui_print "          by Lolokeksu        "
ui_print "*******************************"

case ${API:-$(getprop ro.build.version.sdk 2>/dev/null)} in
    33|34|35|36) ;;
    *) abort "Android 13-16 (API 33-36) is required." ;;
esac

FS=$(stat -f -c %T /data 2>/dev/null)
[ "$FS" = f2fs ] || abort "/data must use F2FS; detected: ${FS:-unknown}."

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
ui_print "- Filesystem /data: F2FS"
ui_print "- Persistent configuration is preserved"
ui_print "- Reboot, then run self-test"
