#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

find "$ROOT/module" -type f -name '*.sh' -exec sh -n {} \;

if command -v busybox >/dev/null 2>&1; then
    find "$ROOT/module" -type f -name '*.sh' -exec busybox ash -n {} \;
fi

if find "$ROOT/module" -type f -name '*.sh' -exec \
    grep -HnE '(^|[^[:alnum:]_])(curl|wget|socat|netcat|nc|eval|setenforce)([^[:alnum:]_]|$)|chmod[[:space:]]+777|https?://' {} +; then
    echo "FAIL: prohibited command or URL found in module shell code" >&2
    exit 1
fi

if command -v file >/dev/null 2>&1 && \
   find "$ROOT/module" -type f -exec file {} \; | grep -q 'ELF'; then
    echo "FAIL: native ELF binary found" >&2
    exit 1
fi

grep -q '^id=f2fs_guardian$' "$ROOT/module/module.prop"
grep -q '^author=Lolokeksu$' "$ROOT/module/module.prop"
grep -q '^version=v1.1$' "$ROOT/module/module.prop"
grep -q '^versionCode=10100$' "$ROOT/module/module.prop"
grep -q '^updateJson=https://raw.githubusercontent.com/lolokeksu/F2FS-Guardian/main/update.json$' \
    "$ROOT/module/module.prop"

grep -q 'Installation will continue with runtime verification.' "$ROOT/module/customize.sh"
grep -q 'if \[ -t 0 \]' "$ROOT/module/action.sh"
grep -q 'if ! IFS= read -r _fg_choice; then' "$ROOT/module/f2fs-guardian.sh"
grep -q '10\. English' "$ROOT/module/f2fs-guardian.sh"
grep -q '10\. Russian' "$ROOT/module/f2fs-guardian.sh"

for command_name in \
    f2g f2status f2check f2request f2cancel f2logs \
    f2doctor f2start f2stop f2profile f2lang f2guardian
do
    test -f "$ROOT/module/system/bin/$command_name"
done

echo "PASS: static security and release checks"
