#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CLI=$ROOT/module/system/bin/f2guardian

sh -n "$CLI"

OUT=$(sh "$CLI" --help)
printf '%s\n' "$OUT" | grep -q '^F2FS Guardian short commands:'
printf '%s\n' "$OUT" | grep -q 'f2doctor'
printf '%s\n' "$OUT" | grep -q 'f2lang LANG'

if sh "$CLI" profile invalid >/dev/null 2>&1; then
    echo "FAIL: invalid profile was accepted" >&2
    exit 1
fi

if sh "$CLI" lang invalid >/dev/null 2>&1; then
    echo "FAIL: invalid language was accepted" >&2
    exit 1
fi

for wrapper in \
    f2g f2status f2check f2request f2cancel f2logs \
    f2doctor f2start f2stop f2profile f2lang
do
    grep -q '^exec /system/bin/f2guardian ' "$ROOT/module/system/bin/$wrapper"
done

echo "PASS: short command dispatcher and wrappers"
