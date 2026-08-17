#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
export BASE_URL

PASS=0
FAIL=0
pass(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
fail(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "========================================"
echo "M10-E Human Acceptance Cleanup Validation"
echo "BASE_URL: $BASE_URL"
echo "========================================"

for path in /health/live /health/ready /info; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path"
done

HTML=$(curl -fsS "${BASE_URL}/control/games/00000000-0000-0000-0000-000000000000" || true)
[[ "$HTML" != *">Game ID<"* ]] && pass "Game ID hidden from operator status card" || fail "Game ID still visible"
[[ "$HTML" != *"Lifecycle Version"* ]] && pass "Lifecycle version hidden from operator UI" || fail "Lifecycle version still visible"
[[ "$HTML" != *"Clock Version"* ]] && pass "Clock version hidden from operator UI" || fail "Clock version still visible"

JS=$(curl -fsS "${BASE_URL}/static/js/control/control.js" || true)
[[ "$JS" == *"game_elapsed_seconds"* ]] && pass "Scoring summary uses durable game elapsed field" || fail "game_elapsed_seconds UI support missing"
[[ "$JS" != *"toLocaleTimeString"* ]] && pass "Wall-clock timestamp removed from scoring summary" || fail "Wall-clock scoring timestamp still present"

if docker compose exec -T app alembic current 2>/dev/null | grep -q "20260817_0007"; then
  pass "Alembic current is 20260817_0007"
else
  fail "Alembic current is not 20260817_0007"
fi

echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M10-E HUMAN ACCEPTANCE CLEANUP PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  exit 0
else
  echo "M10-E HUMAN ACCEPTANCE CLEANUP FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  exit 1
fi
