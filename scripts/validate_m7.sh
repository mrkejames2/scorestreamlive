#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"

PASS=0
FAIL=0

pass() {
    echo "[PASS] $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "[FAIL] $1"
    FAIL=$((FAIL + 1))
}

run_harness() {
    local label="$1"
    local script="$2"
    local output_file
    local rc
    local child_pass
    local child_fail

    output_file=$(mktemp)

    echo ""
    echo "========================================"
    echo "Running ${label}"
    echo "========================================"

    set +e
    BASE_URL="$BASE_URL" "$script" 2>&1 | tee "$output_file"
    rc=${PIPESTATUS[0]}
    set -e

    child_pass=$(grep -oP 'Passed: \K[0-9]+' "$output_file" | tail -1 || true)
    child_fail=$(grep -oP 'Failed: \K[0-9]+' "$output_file" | tail -1 || true)

    child_pass="${child_pass:-0}"
    child_fail="${child_fail:-0}"

    PASS=$((PASS + child_pass))
    FAIL=$((FAIL + child_fail))

    rm -f "$output_file"

    if [ "$rc" -eq 0 ]; then
        pass "${label} process passed"
    else
        fail "${label} process failed with exit code ${rc}"
    fi
}

echo "========================================"
echo "ScoreStreamLive Final Milestone 7 Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"


# validate_m7c.sh is the final checkpoint-aware M7 behavior test.
run_harness "M7-C final behavior harness" "./scripts/validate_m7c.sh"

# Run the proven M6 harness explicitly as an additional final regression
# gate. This keeps the production-validated M6 contract visible.
run_harness "M6 regression harness" "./scripts/validate_m6.sh"

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "M7 VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M7 VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi
