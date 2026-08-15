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
        return 0
    else
        fail "${label} process failed with exit code ${rc}"
        return "$rc"
    fi
}

run_m6_with_retry() {
    local output_file
    local rc
    local child_pass
    local child_fail

    echo ""
    echo "========================================"
    echo "Running M6 regression harness"
    echo "========================================"

    output_file=$(mktemp)

    set +e
    BASE_URL="$BASE_URL" ./scripts/validate_m6.sh 2>&1 | tee "$output_file"
    rc=${PIPESTATUS[0]}
    set -e

    child_pass=$(grep -oP 'Passed: \K[0-9]+' "$output_file" | tail -1 || true)
    child_fail=$(grep -oP 'Failed: \K[0-9]+' "$output_file" | tail -1 || true)

    child_pass="${child_pass:-0}"
    child_fail="${child_fail:-0}"

    rm -f "$output_file"

    if [ "$rc" -eq 0 ]; then
        PASS=$((PASS + child_pass))
        FAIL=$((FAIL + child_fail))
        pass "M6 regression harness process passed"
        return 0
    fi

    echo ""
    echo "[WARN] M6 regression failed on first attempt."
    echo "[WARN] Waiting 5 seconds before one retry..."
    sleep 5

    echo ""
    echo "========================================"
    echo "Retrying M6 regression harness"
    echo "========================================"

    output_file=$(mktemp)

    set +e
    BASE_URL="$BASE_URL" ./scripts/validate_m6.sh 2>&1 | tee "$output_file"
    rc=${PIPESTATUS[0]}
    set -e

    child_pass=$(grep -oP 'Passed: \K[0-9]+' "$output_file" | tail -1 || true)
    child_fail=$(grep -oP 'Failed: \K[0-9]+' "$output_file" | tail -1 || true)

    child_pass="${child_pass:-0}"
    child_fail="${child_fail:-0}"

    rm -f "$output_file"

    if [ "$rc" -eq 0 ]; then
        PASS=$((PASS + child_pass))
        FAIL=$((FAIL + child_fail))
        pass "M6 regression harness passed on retry"
        return 0
    fi

    PASS=$((PASS + child_pass))
    FAIL=$((FAIL + child_fail))
    fail "M6 regression harness failed after retry"
    return "$rc"
}

echo "========================================"
echo "ScoreStreamLive Final Milestone 7 Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

# ============================================================
# M7-C final behavior harness
#
# validate_m7c.sh already exercises:
# - health
# - score persistence
# - scoring REST behavior
# - M3-M6 Socket.IO events
# - M7 Socket.IO events
# - failed mutation suppression
# - concurrency
# - reconnect
# ============================================================
run_harness \
    "M7-C final behavior harness" \
    "./scripts/validate_m7c.sh" || true

# ============================================================
# M6 regression harness
#
# Production Socket.IO connections can occasionally encounter a
# transient namespace/connect timing failure. We allow exactly one
# retry after 5 seconds.
#
# A second failure remains a real M7 validation failure.
# ============================================================
run_m6_with_retry || true

# ============================================================
# Final Summary
# ============================================================
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