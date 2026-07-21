#!/bin/sh
set -eu

. "$(dirname "$0")/testlib.sh"

sh "$MODULE_ROOT/f2fs-guardian.sh" lang ru >/dev/null
grep -q '^MENU_LANGUAGE=0$' "$FG_DATA_DIR/config.conf"

OUT_RU=$(sh "$MODULE_ROOT/f2fs-guardian.sh" status-ui)
printf '%s\n' "$OUT_RU" | grep -q '^Профиль:'

sh "$MODULE_ROOT/f2fs-guardian.sh" lang en >/dev/null
grep -q '^MENU_LANGUAGE=1$' "$FG_DATA_DIR/config.conf"

OUT_EN=$(sh "$MODULE_ROOT/f2fs-guardian.sh" status-ui)
printf '%s\n' "$OUT_EN" | grep -q '^Profile:'

echo "PASS: persistent Russian and English interface selection"
