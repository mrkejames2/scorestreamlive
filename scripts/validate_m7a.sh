#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

URL="localhost:8000"
BASE_URL="${BASE_URL:-http://$URL}"

TS=$(date +%s)
PREFIX="M7A-VALIDATION-${TS}"

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

db_query() {
    local sql="$1"
    docker compose exec -T postgres psql -U scorestreamlive -d scorestreamlive -t -A -c "$sql" 2>/dev/null | tr -d '[:space:]'
}

echo "========================================"
echo "ScoreStreamLive M7-A Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

check_http() {
    local url="$1"
    local expected="$2"
    local label="$3"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${url}")
    if [ "$code" = "$expected" ]; then
        pass "$label"
    else
        fail "$label (expected $expected, got $code)"
    fi
}

check_http "/health/live" "200" "health/live"
check_http "/health/ready" "200" "health/ready"
check_http "/info" "200" "info"

# Historical regression rule:
# M7-A originally required CURRENT == 20260813_0004.
# Later milestones legitimately advance Alembic, so exact-head ownership
# belongs to the ACTIVE milestone validator. Here we verify Alembic is
# healthy, then validate the actual M7 schema/contracts below.
echo ""
echo "Checking Alembic revision health..."
ALEMBIC_CURRENT=$(docker compose exec -T app alembic current 2>/dev/null || true)
if [ -n "$ALEMBIC_CURRENT" ]; then
    pass "Alembic current revision is available"
    echo "  Current: ${ALEMBIC_CURRENT}"
else
    fail "Alembic current revision could not be determined"
fi

TEAM_A_PAYLOAD="{\"name\":\"${PREFIX}-TEAM-A\",\"short_name\":\"TA\"}"
TEAM_A_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/teams" -H "Content-Type: application/json" -d "$TEAM_A_PAYLOAD")
TEAM_A_ID=$(echo "$TEAM_A_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)
if [ -n "$TEAM_A_ID" ]; then
    pass "Team A creation"
else
    fail "Team A creation"
    exit 1
fi

TEAM_B_PAYLOAD="{\"name\":\"${PREFIX}-TEAM-B\",\"short_name\":\"TB\"}"
TEAM_B_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/teams" -H "Content-Type: application/json" -d "$TEAM_B_PAYLOAD")
TEAM_B_ID=$(echo "$TEAM_B_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)
if [ -n "$TEAM_B_ID" ]; then
    pass "Team B creation"
else
    fail "Team B creation"
    exit 1
fi

GAME_PAYLOAD="{\"name\":\"${PREFIX}-GAME\",\"home_team_id\":\"${TEAM_A_ID}\",\"away_team_id\":\"${TEAM_B_ID}\"}"
GAME_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/games" -H "Content-Type: application/json" -d "$GAME_PAYLOAD")
GAME_ID=$(echo "$GAME_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)
if [ -n "$GAME_ID" ]; then
    pass "Game creation"
else
    fail "Game creation"
    exit 1
fi

HOME_SCORE=$(echo "$GAME_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('home_score','MISSING'))")
AWAY_SCORE=$(echo "$GAME_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('away_score','MISSING'))")

if [ "$HOME_SCORE" = "0" ]; then
    pass "New game home_score is 0"
else
    fail "New game home_score is not 0 (got: $HOME_SCORE)"
fi
if [ "$AWAY_SCORE" = "0" ]; then
    pass "New game away_score is 0"
else
    fail "New game away_score is not 0 (got: $AWAY_SCORE)"
fi

GAME_GET=$(curl -s "${BASE_URL}/api/games/${GAME_ID}")
HOME_SCORE_GET=$(echo "$GAME_GET" | python3 -c "import sys,json; print(json.load(sys.stdin).get('home_score','MISSING'))")
AWAY_SCORE_GET=$(echo "$GAME_GET" | python3 -c "import sys,json; print(json.load(sys.stdin).get('away_score','MISSING'))")

if [ "$HOME_SCORE_GET" = "0" ]; then
    pass "Game retrieval home_score exposed"
else
    fail "Game retrieval home_score not exposed (got: $HOME_SCORE_GET)"
fi
if [ "$AWAY_SCORE_GET" = "0" ]; then
    pass "Game retrieval away_score exposed"
else
    fail "Game retrieval away_score not exposed (got: $AWAY_SCORE_GET)"
fi

PATCH_SCORE="{\"home_score\":5}"
curl -s -o /dev/null -w "%{http_code}" -X PATCH "${BASE_URL}/api/games/${GAME_ID}" -H "Content-Type: application/json" -d "$PATCH_SCORE" >/dev/null
GAME_AFTER_PATCH=$(curl -s "${BASE_URL}/api/games/${GAME_ID}")
PATCH_HOME=$(echo "$GAME_AFTER_PATCH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('home_score','MISSING'))")
if [ "$PATCH_HOME" = "0" ]; then
    pass "Game PATCH home_score ignored (score unchanged)"
else
    fail "Game PATCH home_score mutated (got: $PATCH_HOME)"
fi

PATCH_SCORE2="{\"away_score\":3}"
curl -s -o /dev/null -w "%{http_code}" -X PATCH "${BASE_URL}/api/games/${GAME_ID}" -H "Content-Type: application/json" -d "$PATCH_SCORE2" >/dev/null
GAME_AFTER_PATCH2=$(curl -s "${BASE_URL}/api/games/${GAME_ID}")
PATCH_AWAY=$(echo "$GAME_AFTER_PATCH2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('away_score','MISSING'))")
if [ "$PATCH_AWAY" = "0" ]; then
    pass "Game PATCH away_score ignored (score unchanged)"
else
    fail "Game PATCH away_score mutated (got: $PATCH_AWAY)"
fi

PLAYER_PAYLOAD="{\"team_id\":\"${TEAM_A_ID}\",\"first_name\":\"M7A\",\"last_name\":\"Player\",\"jersey_number\":7}"
PLAYER_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "$PLAYER_PAYLOAD")
PLAYER_ID=$(echo "$PLAYER_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)
if [ -n "$PLAYER_ID" ]; then
    pass "Player creation still works"
else
    fail "Player creation broken"
fi

TABLE_EXISTS=$(db_query "SELECT to_regclass('public.scoring_events');")
if [ "$TABLE_EXISTS" = "scoring_events" ]; then
    pass "scoring_events table exists"
else
    fail "scoring_events table missing (got: '$TABLE_EXISTS')"
fi

for col in id game_id team_id player_id event_type created_at; do
    COL_EXISTS=$(db_query "SELECT column_name FROM information_schema.columns WHERE table_name='scoring_events' AND column_name='${col}';")
    if [ "$COL_EXISTS" = "$col" ]; then
        pass "scoring_events has ${col} column"
    else
        fail "scoring_events missing ${col} column (got: '$COL_EXISTS')"
    fi
done

PLAYER_NULLABLE=$(db_query "SELECT is_nullable FROM information_schema.columns WHERE table_name='scoring_events' AND column_name='player_id';")
if [ "$PLAYER_NULLABLE" = "YES" ]; then
    pass "player_id is nullable"
else
    fail "player_id is not nullable (got: '$PLAYER_NULLABLE')"
fi

GAMEID_NULLABLE=$(db_query "SELECT is_nullable FROM information_schema.columns WHERE table_name='scoring_events' AND column_name='game_id';")
if [ "$GAMEID_NULLABLE" = "NO" ]; then
    pass "game_id is NOT NULL"
else
    fail "game_id is nullable (got: '$GAMEID_NULLABLE')"
fi

TEAMID_NULLABLE=$(db_query "SELECT is_nullable FROM information_schema.columns WHERE table_name='scoring_events' AND column_name='team_id';")
if [ "$TEAMID_NULLABLE" = "NO" ]; then
    pass "team_id is NOT NULL"
else
    fail "team_id is nullable (got: '$TEAMID_NULLABLE')"
fi

INDEX_EXISTS=$(db_query "SELECT to_regclass('public.ix_scoring_events_game_id');")
if [ "$INDEX_EXISTS" = "ix_scoring_events_game_id" ]; then
    pass "ix_scoring_events_game_id exists"
else
    fail "ix_scoring_events_game_id missing (got: '$INDEX_EXISTS')"
fi

for col in home_score away_score; do
    COL_EXISTS=$(db_query "SELECT column_name FROM information_schema.columns WHERE table_name='games' AND column_name='${col}';")
    if [ "$COL_EXISTS" = "$col" ]; then
        pass "games table has ${col} column"
    else
        fail "games table missing ${col} column (got: '$COL_EXISTS')"
    fi
done

for col in home_score away_score; do
    COL_NULLABLE=$(db_query "SELECT is_nullable FROM information_schema.columns WHERE table_name='games' AND column_name='${col}';")
    if [ "$COL_NULLABLE" = "NO" ]; then
        pass "games.${col} is NOT NULL"
    else
        fail "games.${col} is nullable (got: '$COL_NULLABLE')"
    fi
done

echo "========================================"
if [ $FAIL -eq 0 ]; then
    echo "M7-A VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M7-A VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi