#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"
BASE_URL="${BASE_URL:-http://localhost:8000}"
export BASE_URL
PASS=0; FAIL=0
pass(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
fail(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "========================================"
echo "ScoreStreamLive M10-H Final Acceptance / Release Gate"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
 code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
 [ "$code" = "200" ] && pass "$path" || fail "$path"
done

for asset in /static/css/control.css /static/js/control/control.js /static/js/control/socket.js /static/js/control/state.js; do
 code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${asset}" || true)
 [ "$code" = "200" ] && pass "$asset" || fail "$asset HTTP ${code}"
done

echo ""
echo "========================================"
echo "Running M10-G cumulative regression certification"
echo "========================================"
set +e
BASE_URL="$BASE_URL" ./scripts/validate_m10g.sh
RC=$?
set -e
[ "$RC" -eq 0 ] && pass "M10-G cumulative regression passed" || fail "M10-G cumulative regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
 echo "M10-H AUTOMATED ACCEPTANCE PASSED"
 echo "Passed: $PASS Failed: $FAIL"
 echo "========================================"
 echo "NEXT: create an M10-H demo and complete M10H_HUMAN_ACCEPTANCE.md"
 exit 0
else
 echo "M10-H AUTOMATED ACCEPTANCE FAILED"
 echo "Passed: $PASS Failed: $FAIL"
 echo "========================================"
 exit 1
fi
