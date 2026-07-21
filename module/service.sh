#!/system/bin/sh
MODDIR=${0%/*}
(
    _fg_wait=0
    while [ "$_fg_wait" -lt 300 ]; do
        if [ "$(getprop sys.boot_completed 2>/dev/null)" = 1 ] && \
           grep -q ' /data ' /proc/self/mountinfo 2>/dev/null; then
            break
        fi
        sleep 5
        _fg_wait=$((_fg_wait + 5))
    done
    exec /system/bin/sh "$MODDIR/f2fs-guardian.sh" daemon
) >/dev/null 2>&1 &
