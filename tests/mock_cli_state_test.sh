#!/bin/sh
set -eu
. "$(dirname "$0")/testlib.sh"
PWNED=$TEST_ROOT/pwned
cat >> "$FG_DATA_DIR/config.conf" <<EOF_CONFIG
ENABLED=\$(touch $PWNED)
UNKNOWN_KEY=123
EOF_CONFIG
sh "$MODULE_ROOT/f2fs-guardian.sh" request >/dev/null
sh "$MODULE_ROOT/f2fs-guardian.sh" cancel >/dev/null
OUT=$(sh "$MODULE_ROOT/f2fs-guardian.sh" status)
printf '%s\n' "$OUT" | grep -q 'Manual request: none'
printf '%s\n' "$OUT" | grep -q 'Last decision: manual maintenance cancelled'
printf '%s\n' "$OUT" | grep -q 'Last run: never'
[ ! -e "$PWNED" ]
echo "PASS: queue/cancel regression and config injection protection"
