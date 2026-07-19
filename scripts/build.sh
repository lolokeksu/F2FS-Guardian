#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DIST=$ROOT/dist
WORK=${TMPDIR:-/tmp}/f2fs-guardian-build.$$
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
rm -rf "$DIST" "$WORK"
mkdir -p "$DIST" "$WORK/module" "$WORK/source"
cp -a "$ROOT/module/." "$WORK/module/"
VERSION=$(sed -n 's/^version=//p' "$ROOT/module/module.prop" | head -n 1)
[ "$VERSION" = v1 ] || { echo "Unexpected version: $VERSION" >&2; exit 1; }
find "$WORK/module" -exec touch -t 198001010000 {} +
(
    cd "$WORK/module"
    find . -type f -o -type l | LC_ALL=C sort | zip -X -q "$DIST/F2FS-Guardian-v1.zip" -@
)
(
    cd "$ROOT"
    find . -path './.git' -prune -o -path './dist' -prune -o -type f -print | LC_ALL=C sort | while IFS= read -r file; do
        mkdir -p "$WORK/source/$(dirname "$file")"
        cp -a "$file" "$WORK/source/$file"
    done
)
find "$WORK/source" -exec touch -t 198001010000 {} +
(
    cd "$WORK/source"
    find . -type f -o -type l | LC_ALL=C sort | zip -X -q "$DIST/F2FS-Guardian-v1-source.zip" -@
)
(
    cd "$DIST"
    sha256sum F2FS-Guardian-v1.zip F2FS-Guardian-v1-source.zip > SHA256SUMS
)
echo "Built release files in $DIST"
