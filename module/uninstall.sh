#!/system/bin/sh
MODDIR=${0%/*}
DATA_DIR=/data/adb/f2fs_guardian
PID_FILE=$DATA_DIR/state/daemon.lock/pid
[ -d "$DATA_DIR/state" ] && touch "$DATA_DIR/state/stop_current" 2>/dev/null
PID=$(cat "$PID_FILE" 2>/dev/null)
case $PID in ''|*[!0-9]*) ;; *) kill "$PID" 2>/dev/null ;; esac
if [ -r "$DATA_DIR/state/owner_mode" ]; then
    OWNED=$(cat "$DATA_DIR/state/owner_mode" 2>/dev/null)
    FS=$(stat -f -c %T /data 2>/dev/null)
    if [ "$FS" = f2fs ]; then
        SOURCE=$(mount 2>/dev/null | awk '$3=="/data" {print $1; exit}')
        INSTANCE=${SOURCE##*/}
        GC=/sys/fs/f2fs/$INSTANCE/gc_urgent
        CURRENT=$(cat "$GC" 2>/dev/null)
        [ "$CURRENT" = "$OWNED" ] && echo 0 > "$GC" 2>/dev/null
    fi
fi
rm -rf "$DATA_DIR" 2>/dev/null
