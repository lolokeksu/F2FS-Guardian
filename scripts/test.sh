#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
"$ROOT/tests/static_checks.sh"
"$ROOT/tests/mock_runtime_test.sh"
"$ROOT/tests/mock_cancel_test.sh"
"$ROOT/tests/mock_conflict_test.sh"
"$ROOT/tests/mock_cli_state_test.sh"
echo "PASS: all tests"
