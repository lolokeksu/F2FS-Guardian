#!/system/bin/sh
#
# KernelSU/SukiSU/APatch Manager Action pages execute action.sh but do not
# reliably provide interactive standard input. Never start a read loop here.
# The full interactive menu remains available from a real terminal via: f2g
#

MODDIR=${0%/*}
ENGINE="$MODDIR/f2fs-guardian.sh"

# A real terminal may provide a usable TTY. Keep this branch for managers or
# shells that genuinely support interactive stdin.
if [ -t 0 ] 2>/dev/null; then
    exec /system/bin/sh "$ENGINE" menu
fi

# Non-interactive Manager Action: show a localized dashboard and exit cleanly.
# This avoids the old EOF -> empty choice -> "Invalid selection" loop.
SYSTEM_LANG=$(
    sed -n 's/^MENU_LANGUAGE=//p' /data/adb/f2fs_guardian/config.conf 2>/dev/null |
        head -n 1
)

case "$SYSTEM_LANG" in
    0)
        /system/bin/sh "$ENGINE" status-ui
        echo
        echo "Интерактивный ввод в окне Action недоступен."
        echo "Откройте Termux или ADB и выполните: f2g"
        echo
        echo "Короткие команды:"
        echo "  f2status   f2check    f2request"
        echo "  f2cancel   f2logs     f2doctor"
        echo "  f2start    f2stop     f2profile"
        echo "  f2lang"
        ;;
    *)
        /system/bin/sh "$ENGINE" status-ui
        echo
        echo "Interactive input is unavailable in the Manager Action window."
        echo "Open Termux or ADB and run: f2g"
        echo
        echo "Short commands:"
        echo "  f2status   f2check    f2request"
        echo "  f2cancel   f2logs     f2doctor"
        echo "  f2start    f2stop     f2profile"
        echo "  f2lang"
        ;;
esac

exit 0
