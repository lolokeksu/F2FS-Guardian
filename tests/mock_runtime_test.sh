#!/bin/sh
set -eu
. "$(dirname "$0")/testlib.sh"
mkdir -p "$TEST_ROOT/bin"
cat > "$TEST_ROOT/bin/sleep" <<'EOS'
#!/bin/sh
exit 0
EOS
chmod +x "$TEST_ROOT/bin/sleep"
PATH=$TEST_ROOT/bin:$PATH
export PATH
sed -i 's/^NORMAL_DURATION_SEC=.*/NORMAL_DURATION_SEC=15/; s/^ACTIVE_RECHECK_SEC=.*/ACTIVE_RECHECK_SEC=5/' "$FG_DATA_DIR/config.conf"
sh "$MODULE_ROOT/f2fs-guardian.sh" request >/dev/null
sh "$MODULE_ROOT/f2fs-guardian.sh" once >/dev/null
[ "$(cat "$FG_SYSFS_ROOT/$FG_INSTANCE/gc_urgent")" = 0 ]
[ -s "$FG_DATA_DIR/state/last_run_epoch" ]
grep -q '^maintenance completed:' "$FG_DATA_DIR/state/last_decision"
[ ! -e "$FG_DATA_DIR/state/manual_request" ]
echo "PASS: successful GC lifecycle mock"
