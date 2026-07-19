#!/bin/sh
set -eu

TEST_ROOT=${TEST_ROOT:-$(mktemp -d)}
MODULE_ROOT=${MODULE_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../module" && pwd)}
export FG_MODDIR=$MODULE_ROOT
export FG_DATA_DIR=$TEST_ROOT/data
export FG_SYSFS_ROOT=$TEST_ROOT/sys/fs/f2fs
export FG_INSTANCE=dm-51
export FG_BLOCK_STAT=$TEST_ROOT/sys/class/block/dm-51/stat
export FG_DATA_FS=f2fs
export FG_DATA_SOURCE=/dev/block/dm-51
export FG_STORAGE_USAGE=90
export FG_BATTERY_LEVEL=90
export FG_BATTERY_TEMP=350
export FG_CHARGING=1
export FG_SCREEN_ON=0
export FG_IO_OPS=0
mkdir -p "$FG_DATA_DIR/state" "$FG_DATA_DIR/logs" "$FG_SYSFS_ROOT/$FG_INSTANCE" "$(dirname "$FG_BLOCK_STAT")"
printf '0\n' > "$FG_SYSFS_ROOT/$FG_INSTANCE/gc_urgent"
printf '1000\n' > "$FG_SYSFS_ROOT/$FG_INSTANCE/free_segments"
printf '600\n' > "$FG_SYSFS_ROOT/$FG_INSTANCE/dirty_segments"
printf '0 0 0 0 0 0 0 0 0 0 0\n' > "$FG_BLOCK_STAT"
cp "$MODULE_ROOT/config/default.conf" "$FG_DATA_DIR/config.conf"
NOW=$(date +%s)
printf '%s\n' $((NOW - 7200)) > "$FG_DATA_DIR/state/screen_off_since"

cleanup_test() {
    rm -rf "$TEST_ROOT"
}
trap cleanup_test EXIT HUP INT TERM
