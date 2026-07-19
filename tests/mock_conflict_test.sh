#!/bin/sh
set -eu
. "$(dirname "$0")/testlib.sh"
printf '1\n' > "$FG_SYSFS_ROOT/$FG_INSTANCE/gc_urgent"
sh "$MODULE_ROOT/f2fs-guardian.sh" request >/dev/null
sh "$MODULE_ROOT/f2fs-guardian.sh" once >/dev/null || true
[ "$(cat "$FG_SYSFS_ROOT/$FG_INSTANCE/gc_urgent")" = 1 ]
grep -q 'conflict: gc_urgent already 1' "$FG_DATA_DIR/state/last_decision"
echo "PASS: external ownership conflict mock"
