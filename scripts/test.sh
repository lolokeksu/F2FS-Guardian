#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

"$ROOT/tests/static_checks.sh"
"$ROOT/tests/mock_runtime_test.sh"
"$ROOT/tests/mock_cancel_test.sh"
"$ROOT/tests/mock_conflict_test.sh"
"$ROOT/tests/mock_cli_state_test.sh"
"$ROOT/tests/mock_menu_eof_test.sh"
"$ROOT/tests/mock_language_test.sh"
"$ROOT/tests/mock_short_cli_test.sh"

if command -v python3 >/dev/null 2>&1; then
    python3 "$ROOT/tests/readme_sync_test.py"
else
    echo "SKIP: README synchronization test requires python3"
fi

echo "PASS: all tests"
