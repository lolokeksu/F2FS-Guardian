#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
find "$ROOT/module" -type f -name '*.sh' -exec sh -n {} \;
if command -v busybox >/dev/null 2>&1; then
    find "$ROOT/module" -type f -name '*.sh' -exec busybox ash -n {} \;
fi
if find "$ROOT/module" -type f -name '*.sh' -exec grep -HnE '(^|[^[:alnum:]_])(curl|wget|socat|netcat|nc|eval|setenforce)([^[:alnum:]_]|$)|chmod[[:space:]]+777|https?://' {} +; then
    echo "FAIL: prohibited command or URL found in module" >&2
    exit 1
fi
if find "$ROOT/module" -type f -exec file {} \; | grep -q 'ELF'; then
    echo "FAIL: native ELF binary found" >&2
    exit 1
fi
grep -q '^author=Lolokeksu$' "$ROOT/module/module.prop"
grep -q '^version=v1$' "$ROOT/module/module.prop"
grep -q '^versionCode=10001$' "$ROOT/module/module.prop"
echo "PASS: static security checks"
