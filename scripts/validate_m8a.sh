#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"

TS=$(date +%s)
PREFIX="M8A-VALIDATION-${TS}"

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

check_http() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local code

    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}")

    if [ "$code" = "$expected" ]; then
        pass "$label"
    else
        fail "$label (expected $expected, got $code)"
    fi
}

db_query() {
    local sql="$1"

    docker compose exec -T postgres \
        psql \
        -v ON_ERROR_STOP=1 \
        -U scorestreamlive \
        -d scorestreamlive \
        -t -A \
        -c "$sql" \
        2>/dev/null \
        | tr -d '[:space:]'
}

db_expect_success() {
    local sql="$1"
    local label="$2"

    if docker compose exec -T postgres \
        psql \
        -v ON_ERROR_STOP=1 \
        -U scorestreamlive \
        -d scorestreamlive \
        -c "$sql" \
        >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label"
    fi
}

db_expect_failure() {
    local sql="$1"
    local label="$2"

    set +e

    docker compose exec -T postgres \
        psql \
        -v ON_ERROR_STOP=1 \
        -U scorestreamlive \
        -d scorestreamlive \
        -c "$sql" \
        >/dev/null 2>&1

    local rc=$?

    set -e

    if [ "$rc" -ne 0 ]; then
        pass "$label"
    else
        fail "$label"
    fi
}

new_uuid() {
    python3 -c "import uuid; print(uuid.uuid4())"
}

echo "========================================"
echo "ScoreStreamLive M8-A Persistence Regression"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

# ============================================================
# 1. Health
# ============================================================
check_http "/health/live" "200" "health/live"
check_http "/health/ready" "200" "health/ready"
check_http "/info" "200" "info"

# ============================================================
# 2. M8 migration presence
#
# Do NOT use:
#
#     alembic history | grep -q ...
#
# with `set -o pipefail`.
#
# grep -q can close the pipe immediately after finding the match.
# The producer may then receive SIGPIPE, causing a false pipeline
# failure even though the revision was found.
#
# Capture Alembic output first, then inspect the completed output.
# ============================================================
echo ""
echo "Checking M8 migration presence..."

ALEMBIC_HISTORY=$(docker compose exec -T app alembic history 2>/dev/null || true)

if grep -F "20260815_0006" <<< "$ALEMBIC_HISTORY" >/dev/null; then
    pass "Alembic history contains 20260815_0006"
else
    echo "$ALEMBIC_HISTORY"
    fail "Alembic history does not contain 20260815_0006"
fi

# ============================================================
# 3. Create parent Teams and Game
# ============================================================
TEAM_A_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/teams" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${PREFIX}-TEAM-A\",\"short_name\":\"TA\"}")

TEAM_A_ID=$(echo "$TEAM_A_RESPONSE" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" \
    2>/dev/null || true)

if [ -n "$TEAM_A_ID" ]; then
    pass "Team A creation"
else
    fail "Team A creation"
fi

TEAM_B_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/teams" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${PREFIX}-TEAM-B\",\"short_name\":\"TB\"}")

TEAM_B_ID=$(echo "$TEAM_B_RESPONSE" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" \
    2>/dev/null || true)

if [ -n "$TEAM_B_ID" ]; then
    pass "Team B creation"
else
    fail "Team B creation"
fi

GAME_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/games" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${PREFIX}-GAME\",\"home_team_id\":\"${TEAM_A_ID}\",\"away_team_id\":\"${TEAM_B_ID}\"}")

GAME_ID=$(echo "$GAME_RESPONSE" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" \
    2>/dev/null || true)

if [ -n "$GAME_ID" ]; then
    pass "Game creation"
else
    fail "Game creation"
fi

# ============================================================
# 4. game_clocks table
# ============================================================
TABLE_EXISTS=$(db_query "SELECT to_regclass('public.game_clocks');")

if [ "$TABLE_EXISTS" = "game_clocks" ]; then
    pass "game_clocks table exists"
else
    fail "game_clocks table missing"
fi

# ============================================================
# 5. Required columns
# ============================================================
for col in \
    id \
    game_id \
    mode \
    status \
    duration_seconds \
    elapsed_seconds \
    running_since \
    version \
    created_at \
    updated_at
do
    FOUND=$(db_query "
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name='game_clocks'
          AND column_name='${col}';
    ")

    if [ "$FOUND" = "$col" ]; then
        pass "game_clocks has ${col} column"
    else
        fail "game_clocks missing ${col} column"
    fi
done

# ============================================================
# 6. Nullability
# ============================================================
for col in \
    id \
    game_id \
    mode \
    status \
    duration_seconds \
    elapsed_seconds \
    version \
    created_at \
    updated_at
do
    NULLABLE=$(db_query "
        SELECT is_nullable
        FROM information_schema.columns
        WHERE table_name='game_clocks'
          AND column_name='${col}';
    ")

    if [ "$NULLABLE" = "NO" ]; then
        pass "game_clocks.${col} is NOT NULL"
    else
        fail "game_clocks.${col} should be NOT NULL"
    fi
done

RUNNING_NULLABLE=$(db_query "
    SELECT is_nullable
    FROM information_schema.columns
    WHERE table_name='game_clocks'
      AND column_name='running_since';
")

if [ "$RUNNING_NULLABLE" = "YES" ]; then
    pass "game_clocks.running_since is nullable"
else
    fail "game_clocks.running_since should be nullable"
fi

# ============================================================
# 7. Constraints
# ============================================================
for constraint in \
    uq_game_clocks_game_id \
    ck_game_clocks_mode \
    ck_game_clocks_status \
    ck_game_clocks_duration_positive \
    ck_game_clocks_elapsed_nonnegative \
    ck_game_clocks_version_positive
do
    FOUND=$(db_query "
        SELECT conname
        FROM pg_constraint
        WHERE conname='${constraint}';
    ")

    if [ "$FOUND" = "$constraint" ]; then
        pass "Constraint ${constraint} exists"
    else
        fail "Constraint ${constraint} missing"
    fi
done

FK_RULE=$(db_query "
    SELECT rc.delete_rule
    FROM information_schema.referential_constraints rc
    WHERE rc.constraint_name = (
        SELECT tc.constraint_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name='game_clocks'
          AND tc.constraint_type='FOREIGN KEY'
          AND kcu.column_name='game_id'
        LIMIT 1
    );
")

if [ "$FK_RULE" = "RESTRICT" ]; then
    pass "game_id FK uses RESTRICT"
else
    fail "game_id FK does not use RESTRICT"
fi

# ============================================================
# 8. Valid clock persistence + defaults
# ============================================================
CLOCK_ID=$(new_uuid)

db_expect_success "
    INSERT INTO game_clocks (
        id,
        game_id,
        mode,
        duration_seconds,
        created_at,
        updated_at
    )
    VALUES (
        '${CLOCK_ID}',
        '${GAME_ID}',
        'count_up',
        2700,
        NOW(),
        NOW()
    );
" "Valid count-up GameClock persists"

MODE=$(db_query "
    SELECT mode
    FROM game_clocks
    WHERE id='${CLOCK_ID}';
")

STATUS=$(db_query "
    SELECT status
    FROM game_clocks
    WHERE id='${CLOCK_ID}';
")

DURATION=$(db_query "
    SELECT duration_seconds
    FROM game_clocks
    WHERE id='${CLOCK_ID}';
")

ELAPSED=$(db_query "
    SELECT elapsed_seconds
    FROM game_clocks
    WHERE id='${CLOCK_ID}';
")

VERSION=$(db_query "
    SELECT version
    FROM game_clocks
    WHERE id='${CLOCK_ID}';
")

RUNNING=$(db_query "
    SELECT COALESCE(running_since::text,'NULL')
    FROM game_clocks
    WHERE id='${CLOCK_ID}';
")

[ "$MODE" = "count_up" ] \
    && pass "mode persisted" \
    || fail "mode persistence"

[ "$STATUS" = "stopped" ] \
    && pass "status default stopped" \
    || fail "status default"

[ "$DURATION" = "2700" ] \
    && pass "duration persisted" \
    || fail "duration persistence"

[ "$ELAPSED" = "0" ] \
    && pass "elapsed default 0" \
    || fail "elapsed default"

[ "$VERSION" = "1" ] \
    && pass "version default 1" \
    || fail "version default"

[ "$RUNNING" = "NULL" ] \
    && pass "running_since defaults null" \
    || fail "running_since default"

# ============================================================
# 9. One clock per Game
# ============================================================
DUP_ID=$(new_uuid)

db_expect_failure "
    INSERT INTO game_clocks (
        id,
        game_id,
        mode,
        duration_seconds,
        created_at,
        updated_at
    )
    VALUES (
        '${DUP_ID}',
        '${GAME_ID}',
        'count_down',
        1200,
        NOW(),
        NOW()
    );
" "Duplicate GameClock rejected"

# ============================================================
# 10. Game FK
# ============================================================
MISSING_GAME=$(new_uuid)
BAD_ID=$(new_uuid)

db_expect_failure "
    INSERT INTO game_clocks (
        id,
        game_id,
        mode,
        duration_seconds,
        created_at,
        updated_at
    )
    VALUES (
        '${BAD_ID}',
        '${MISSING_GAME}',
        'count_up',
        2700,
        NOW(),
        NOW()
    );
" "Missing Game FK rejected"

# ============================================================
# Summary
# ============================================================
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "M8-A PERSISTENCE REGRESSION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M8-A PERSISTENCE REGRESSION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi