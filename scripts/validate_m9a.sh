#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"
PASS=0
FAIL=0

pass(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
fail(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

db_query() {
    docker compose exec -T postgres \
        psql -v ON_ERROR_STOP=1 -U scorestreamlive -d scorestreamlive \
        -t -A -c "$1" 2>/dev/null | tr -d '[:space:]'
}

echo "========================================"
echo "ScoreStreamLive M9-A Persistence Regression"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}")
    [ "$code" = "200" ] && pass "$path" || fail "$path"
done

history=$(docker compose exec -T app alembic history 2>/dev/null || true)
if grep -F "20260815_0006" <<< "$history" >/dev/null; then
    pass "Alembic history contains M9 revision 20260815_0006"
else
    fail "Alembic history missing M9 revision 20260815_0006"
fi

table=$(db_query "SELECT to_regclass('public.game_lifecycles');")
[ "$table" = "game_lifecycles" ] \
    && pass "game_lifecycles table exists" \
    || fail "game_lifecycles table missing"

for col in id game_id phase version created_at updated_at; do
    found=$(db_query "SELECT column_name FROM information_schema.columns WHERE table_name='game_lifecycles' AND column_name='${col}';")
    [ "$found" = "$col" ] \
        && pass "game_lifecycles has ${col}" \
        || fail "game_lifecycles missing ${col}"
done

for constraint in \
    uq_game_lifecycles_game_id \
    ck_game_lifecycles_phase \
    ck_game_lifecycles_version_positive
do
    found=$(db_query "SELECT conname FROM pg_constraint WHERE conname='${constraint}';")
    [ "$found" = "$constraint" ] \
        && pass "Constraint ${constraint} exists" \
        || fail "Constraint ${constraint} missing"
done

echo "========================================"
if [ "$FAIL" -eq 0 ]; then
    echo "M9-A PERSISTENCE REGRESSION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    exit 0
else
    echo "M9-A PERSISTENCE REGRESSION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    exit 1
fi
