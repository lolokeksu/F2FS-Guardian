#!/system/bin/sh
MODDIR=${0%/*}
nohup /system/bin/sh "$MODDIR/f2fs-guardian.sh" daemon >/dev/null 2>&1 &
