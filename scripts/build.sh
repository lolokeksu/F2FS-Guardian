#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DIST=$ROOT/dist
WORK=${TMPDIR:-/tmp}/f2fs-guardian-build.$$
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

VERSION=$(sed -n 's/^version=//p' "$ROOT/module/module.prop" | head -n 1)
VERSION_CODE=$(sed -n 's/^versionCode=//p' "$ROOT/module/module.prop" | head -n 1)

case "$VERSION" in
    v[0-9]*)
        ;;
    *)
        echo "Invalid module version: $VERSION" >&2
        exit 1
        ;;
esac

case "$VERSION_CODE" in
    ''|*[!0-9]*)
        echo "Invalid versionCode: $VERSION_CODE" >&2
        exit 1
        ;;
esac

BASENAME=F2FS-Guardian-$VERSION

rm -rf "$DIST" "$WORK"
mkdir -p "$DIST" "$WORK/module" "$WORK/source"

cp -a "$ROOT/module/." "$WORK/module/"
find "$WORK/module" -exec touch -t 198001010000 {} +

(
    cd "$WORK/module"
    find . \( -type f -o -type l \) -print | LC_ALL=C sort |
        zip -X -q "$DIST/$BASENAME.zip" -@
)

(
    cd "$ROOT"
    find . \
        -path './.git' -prune -o \
        -path './dist' -prune -o \
        -type f -print |
        LC_ALL=C sort |
        while IFS= read -r file; do
            mkdir -p "$WORK/source/$(dirname "$file")"
            cp -a "$file" "$WORK/source/$file"
        done
)

find "$WORK/source" -exec touch -t 198001010000 {} +

(
    cd "$WORK/source"
    find . \( -type f -o -type l \) -print | LC_ALL=C sort |
        zip -X -q "$DIST/$BASENAME-source.zip" -@
)

(
    cd "$DIST"
    sha256sum "$BASENAME.zip" "$BASENAME-source.zip" > SHA256SUMS
)

echo "Built $BASENAME release files in $DIST"
