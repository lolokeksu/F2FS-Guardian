#!/bin/sh
set -eu

. "$(dirname "$0")/testlib.sh"

sed -i 's/^MENU_LANGUAGE=.*/MENU_LANGUAGE=1/' "$FG_DATA_DIR/config.conf"

OUT=$(
    sh "$MODULE_ROOT/f2fs-guardian.sh" menu </dev/null 2>&1 || true
)

printf '%s\n' "$OUT" | grep -q 'Interactive input is unavailable'
if printf '%s\n' "$OUT" | grep -q 'Invalid selection'; then
    echo "FAIL: menu loops on EOF" >&2
    exit 1
fi

COUNT=$(printf '%s\n' "$OUT" | grep -c 'Interactive input is unavailable' || true)
[ "$COUNT" = 1 ]

echo "PASS: non-interactive menu exits once without Invalid selection"
