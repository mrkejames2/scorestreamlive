#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"
TS=$(date +%s)
PREFIX="M8B-VALIDATION-${TS}"

PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

http_json() {
    local method="$1"
    local path="$2"
    local payload="${3:-}"
    local body_file
    body_file=$(mktemp)

    local code
    if [ -n "$payload" ]; then
        code=$(curl -s -o "$body_file" -w "%{http_code}" \
            -X "$method" \
            "${BASE_URL}${path}" \
            -H "Content-Type: application/json" \
            -d "$payload")
    else
        code=$(curl -s -o "$body_file" -w "%{http_code}" \
            -X "$method" \
            "${BASE_URL}${path}")
    fi

    cat "$body_file"
    rm -f "$body_file"
    printf "\nHTTP_STATUS:%s\n" "$code"
}

json_value() {
    local json="$1"
    local key="$2"
    echo "$json" | python3 -c \
        "import sys,json; data=json.load(sys.stdin); v=data.get('$key'); print('NULL' if v is None else str(v).lower() if isinstance(v,bool) else v)"
}

strip_status() {
    sed '/^HTTP_STATUS:/d'
}

status_from() {
    grep '^HTTP_STATUS:' | cut -d: -f2
}

create_team() {
    local name="$1"
    local short="$2"
    curl -s -X POST "${BASE_URL}/api/teams" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${name}\",\"short_name\":\"${short}\"}"
}

create_game() {
    local name="$1"
    local home="$2"
    local away="$3"
    curl -s -X POST "${BASE_URL}/api/games" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${name}\",\"home_team_id\":\"${home}\",\"away_team_id\":\"${away}\"}"
}

echo "========================================"
echo "ScoreStreamLive M8-B Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

# ============================================================
# 1. Health / migration
# ============================================================
for path in /health/live /health/ready /info; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}")
    [ "$CODE" = "200" ] && pass "$path" || fail "$path"
done

# ============================================================
# 2. Setup Teams/Games
# ============================================================
TEAM_A=$(create_team "${PREFIX}-TEAM-A" "TA")
TEAM_A_ID=$(json_value "$TEAM_A" "id")
[ -n "$TEAM_A_ID" ] && pass "Team A created" || fail "Team A creation"

TEAM_B=$(create_team "${PREFIX}-TEAM-B" "TB")
TEAM_B_ID=$(json_value "$TEAM_B" "id")
[ -n "$TEAM_B_ID" ] && pass "Team B created" || fail "Team B creation"

GAME_A=$(create_game "${PREFIX}-GAME-A" "$TEAM_A_ID" "$TEAM_B_ID")
GAME_A_ID=$(json_value "$GAME_A" "id")
[ -n "$GAME_A_ID" ] && pass "Game A created" || fail "Game A creation"

GAME_B=$(create_game "${PREFIX}-GAME-B" "$TEAM_A_ID" "$TEAM_B_ID")
GAME_B_ID=$(json_value "$GAME_B" "id")
[ -n "$GAME_B_ID" ] && pass "Game B created" || fail "Game B creation"

# ============================================================
# 3. Create count-up clock
# ============================================================
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock" \
    '{"mode":"count_up","duration_seconds":2700}')
CODE=$(echo "$RAW" | status_from)
BODY=$(echo "$RAW" | strip_status)

[ "$CODE" = "201" ] && pass "Create count-up clock returns 201" || fail "Create count-up clock expected 201 got $CODE"
[ "$(json_value "$BODY" "mode")" = "count_up" ] && pass "Count-up mode returned" || fail "Count-up mode"
[ "$(json_value "$BODY" "status")" = "stopped" ] && pass "Initial status stopped" || fail "Initial status"
[ "$(json_value "$BODY" "elapsed_seconds")" = "0" ] && pass "Initial elapsed 0" || fail "Initial elapsed"
[ "$(json_value "$BODY" "version")" = "1" ] && pass "Initial version 1" || fail "Initial version"
[ "$(json_value "$BODY" "authoritative_elapsed_seconds")" = "0" ] && pass "Initial authoritative elapsed 0" || fail "Initial authoritative elapsed"
[ "$(json_value "$BODY" "display_seconds")" = "0" ] && pass "Initial count-up display 0" || fail "Initial count-up display"
[ "$(json_value "$BODY" "server_time")" != "NULL" ] && pass "server_time returned" || fail "server_time missing"

# Duplicate
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock" \
    '{"mode":"count_up","duration_seconds":2700}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "409" ] && pass "Duplicate clock rejected 409" || fail "Duplicate clock expected 409 got $CODE"

# Missing Game
MISSING_GAME=$(python3 -c "import uuid; print(uuid.uuid4())")
RAW=$(http_json POST "/api/games/${MISSING_GAME}/clock" \
    '{"mode":"count_up","duration_seconds":2700}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "404" ] && pass "Missing Game clock creation rejected 404" || fail "Missing Game expected 404 got $CODE"

# Schema validation
RAW=$(http_json POST "/api/games/${GAME_B_ID}/clock" \
    '{"mode":"sideways","duration_seconds":2700}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "422" ] && pass "Invalid mode rejected 422" || fail "Invalid mode expected 422 got $CODE"

RAW=$(http_json POST "/api/games/${GAME_B_ID}/clock" \
    '{"mode":"count_down","duration_seconds":0}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "422" ] && pass "Zero duration rejected 422" || fail "Zero duration expected 422 got $CODE"

RAW=$(http_json POST "/api/games/${GAME_B_ID}/clock" \
    '{"mode":"count_down","duration_seconds":-1}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "422" ] && pass "Negative duration rejected 422" || fail "Negative duration expected 422 got $CODE"

# ============================================================
# 4. GET clock
# ============================================================
RAW=$(http_json GET "/api/games/${GAME_A_ID}/clock")
CODE=$(echo "$RAW" | status_from)
BODY=$(echo "$RAW" | strip_status)

[ "$CODE" = "200" ] && pass "GET clock returns 200" || fail "GET clock"
[ "$(json_value "$BODY" "game_id")" = "$GAME_A_ID" ] && pass "GET clock game_id matches" || fail "GET clock game_id"

RAW=$(http_json GET "/api/games/${MISSING_GAME}/clock")
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "404" ] && pass "Missing clock GET returns 404" || fail "Missing clock GET"

# ============================================================
# 5. Start count-up
# ============================================================
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/start" '{"expected_version":1}')
CODE=$(echo "$RAW" | status_from)
BODY=$(echo "$RAW" | strip_status)

[ "$CODE" = "200" ] && pass "Start clock returns 200" || fail "Start clock"
[ "$(json_value "$BODY" "status")" = "running" ] && pass "Start sets running" || fail "Start status"
[ "$(json_value "$BODY" "version")" = "2" ] && pass "Start increments version to 2" || fail "Start version"
[ "$(json_value "$BODY" "running_since")" != "NULL" ] && pass "Start sets running_since" || fail "Start running_since"

sleep 2

RAW=$(http_json GET "/api/games/${GAME_A_ID}/clock")
BODY=$(echo "$RAW" | strip_status)
RUNNING_ELAPSED=$(json_value "$BODY" "authoritative_elapsed_seconds")

if [ "$RUNNING_ELAPSED" -ge 1 ] && [ "$RUNNING_ELAPSED" -le 6 ]; then
    pass "Count-up advances from timestamp anchor"
else
    fail "Count-up elapsed outside tolerance: $RUNNING_ELAPSED"
fi

# Invalid start while already running
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/start" '{"expected_version":2}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "409" ] && pass "Start while running rejected 409" || fail "Start while running expected 409 got $CODE"

# Config while running rejected
RAW=$(http_json PATCH "/api/games/${GAME_A_ID}/clock" \
    '{"expected_version":2,"duration_seconds":3000}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "409" ] && pass "Configuration while running rejected 409" || fail "Config while running expected 409 got $CODE"

# Reset while running rejected
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/reset" '{"expected_version":2}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "409" ] && pass "Reset while running rejected 409" || fail "Reset while running expected 409 got $CODE"

# ============================================================
# 6. Pause / freeze
# ============================================================
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/pause" '{"expected_version":2}')
CODE=$(echo "$RAW" | status_from)
BODY=$(echo "$RAW" | strip_status)

[ "$CODE" = "200" ] && pass "Pause returns 200" || fail "Pause"
[ "$(json_value "$BODY" "status")" = "paused" ] && pass "Pause sets paused" || fail "Pause status"
[ "$(json_value "$BODY" "version")" = "3" ] && pass "Pause increments version to 3" || fail "Pause version"
[ "$(json_value "$BODY" "running_since")" = "NULL" ] && pass "Pause clears running_since" || fail "Pause running_since"

PAUSED_ELAPSED=$(json_value "$BODY" "authoritative_elapsed_seconds")
sleep 2

RAW=$(http_json GET "/api/games/${GAME_A_ID}/clock")
BODY=$(echo "$RAW" | strip_status)
PAUSED_AFTER=$(json_value "$BODY" "authoritative_elapsed_seconds")

[ "$PAUSED_AFTER" = "$PAUSED_ELAPSED" ] && pass "Paused clock does not advance" || fail "Paused clock advanced ($PAUSED_ELAPSED -> $PAUSED_AFTER)"

# Pause again rejected
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/pause" '{"expected_version":3}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "409" ] && pass "Pause while paused rejected 409" || fail "Pause while paused expected 409 got $CODE"

# ============================================================
# 7. Resume
# ============================================================
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/resume" '{"expected_version":3}')
CODE=$(echo "$RAW" | status_from)
BODY=$(echo "$RAW" | strip_status)

[ "$CODE" = "200" ] && pass "Resume returns 200" || fail "Resume"
[ "$(json_value "$BODY" "status")" = "running" ] && pass "Resume sets running" || fail "Resume status"
[ "$(json_value "$BODY" "version")" = "4" ] && pass "Resume increments version to 4" || fail "Resume version"

sleep 2
RAW=$(http_json GET "/api/games/${GAME_A_ID}/clock")
BODY=$(echo "$RAW" | strip_status)
RESUMED_ELAPSED=$(json_value "$BODY" "authoritative_elapsed_seconds")

if [ "$RESUMED_ELAPSED" -gt "$PAUSED_ELAPSED" ]; then
    pass "Resume continues accumulated elapsed time"
else
    fail "Resume did not advance ($PAUSED_ELAPSED -> $RESUMED_ELAPSED)"
fi

# ============================================================
# 8. Stale expected version
# ============================================================
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/pause" '{"expected_version":3}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "409" ] && pass "Stale expected_version rejected 409" || fail "Stale version expected 409 got $CODE"

RAW=$(http_json GET "/api/games/${GAME_A_ID}/clock")
BODY=$(echo "$RAW" | strip_status)
[ "$(json_value "$BODY" "version")" = "4" ] && pass "Stale mutation leaves version unchanged" || fail "Stale mutation changed version"

# Correct pause for configuration/reset
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/pause" '{"expected_version":4}')
BODY=$(echo "$RAW" | strip_status)
[ "$(json_value "$BODY" "version")" = "5" ] && pass "Second valid pause increments version to 5" || fail "Second pause version"

# ============================================================
# 9. Configuration + elapsed preservation
# ============================================================
BEFORE_CONFIG_ELAPSED=$(json_value "$BODY" "elapsed_seconds")

RAW=$(http_json PATCH "/api/games/${GAME_A_ID}/clock" \
    '{"expected_version":5,"mode":"count_down","duration_seconds":5}')
CODE=$(echo "$RAW" | status_from)
BODY=$(echo "$RAW" | strip_status)

[ "$CODE" = "200" ] && pass "Configuration update returns 200" || fail "Configuration update"
[ "$(json_value "$BODY" "mode")" = "count_down" ] && pass "Mode updates to count_down" || fail "Mode update"
[ "$(json_value "$BODY" "duration_seconds")" = "5" ] && pass "Duration updates to 5" || fail "Duration update"
[ "$(json_value "$BODY" "version")" = "6" ] && pass "Configuration increments version to 6" || fail "Configuration version"
[ "$(json_value "$BODY" "elapsed_seconds")" = "$BEFORE_CONFIG_ELAPSED" ] && pass "Configuration preserves elapsed_seconds" || fail "Configuration changed elapsed_seconds"

# Empty configuration rejected by schema
RAW=$(http_json PATCH "/api/games/${GAME_A_ID}/clock" '{"expected_version":6}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "422" ] && pass "Empty configuration rejected 422" || fail "Empty config expected 422 got $CODE"

# ============================================================
# 10. Reset
# ============================================================
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/reset" '{"expected_version":6}')
CODE=$(echo "$RAW" | status_from)
BODY=$(echo "$RAW" | strip_status)

[ "$CODE" = "200" ] && pass "Reset returns 200" || fail "Reset"
[ "$(json_value "$BODY" "status")" = "stopped" ] && pass "Reset sets stopped" || fail "Reset status"
[ "$(json_value "$BODY" "elapsed_seconds")" = "0" ] && pass "Reset elapsed 0" || fail "Reset elapsed"
[ "$(json_value "$BODY" "running_since")" = "NULL" ] && pass "Reset running_since null" || fail "Reset running_since"
[ "$(json_value "$BODY" "version")" = "7" ] && pass "Reset increments version to 7" || fail "Reset version"
[ "$(json_value "$BODY" "mode")" = "count_down" ] && pass "Reset preserves mode" || fail "Reset mode"
[ "$(json_value "$BODY" "duration_seconds")" = "5" ] && pass "Reset preserves duration" || fail "Reset duration"
[ "$(json_value "$BODY" "display_seconds")" = "5" ] && pass "Stopped count-down displays duration" || fail "Stopped count-down display"

# ============================================================
# 11. Count-down behavior and zero clamp
# ============================================================
RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/start" '{"expected_version":7}')
BODY=$(echo "$RAW" | strip_status)
[ "$(json_value "$BODY" "version")" = "8" ] && pass "Count-down start increments version" || fail "Count-down start version"

sleep 2

RAW=$(http_json GET "/api/games/${GAME_A_ID}/clock")
BODY=$(echo "$RAW" | strip_status)
COUNTDOWN_DISPLAY=$(json_value "$BODY" "display_seconds")

if [ "$COUNTDOWN_DISPLAY" -le 4 ] && [ "$COUNTDOWN_DISPLAY" -ge 1 ]; then
    pass "Count-down display decreases"
else
    fail "Count-down display outside tolerance: $COUNTDOWN_DISPLAY"
fi

sleep 4

RAW=$(http_json GET "/api/games/${GAME_A_ID}/clock")
BODY=$(echo "$RAW" | strip_status)
[ "$(json_value "$BODY" "display_seconds")" = "0" ] && pass "Count-down display clamps at zero" || fail "Count-down did not clamp at zero"

RAW=$(http_json POST "/api/games/${GAME_A_ID}/clock/pause" '{"expected_version":8}')
CODE=$(echo "$RAW" | status_from)
[ "$CODE" = "200" ] && pass "Count-down clock can pause after zero" || fail "Pause after zero"

# ============================================================
# 12. Soccer added-time helper boundaries
# ============================================================
SOCCER=$(docker compose exec -T app python3 - <<'PY'
from app.services.game_clock_service import calculate_soccer_added_time_minute
cases = [2699, 2700, 2759, 2760, 2819, 2820]
for value in cases:
    result = calculate_soccer_added_time_minute(value, 2700)
    print(f"{value}:{'None' if result is None else result}")
PY
)

for expected in \
    "2699:None" \
    "2700:1" \
    "2759:1" \
    "2760:2" \
    "2819:2" \
    "2820:3"
do
    if echo "$SOCCER" | grep -q "^${expected}$"; then
        pass "Soccer added-time boundary ${expected}"
    else
        fail "Soccer added-time boundary ${expected}"
    fi
done

# ============================================================
# 13. Simultaneous same-version controllers
# ============================================================
GAME_C=$(create_game "${PREFIX}-GAME-CONCURRENT" "$TEAM_A_ID" "$TEAM_B_ID")
GAME_C_ID=$(json_value "$GAME_C" "id")

RAW=$(http_json POST "/api/games/${GAME_C_ID}/clock" \
    '{"mode":"count_up","duration_seconds":2700}')
BODY=$(echo "$RAW" | strip_status)
[ "$(json_value "$BODY" "version")" = "1" ] && pass "Concurrent test clock initialized version 1" || fail "Concurrent clock init"

CONCURRENT_RESULT=$(BASE_URL="$BASE_URL" GAME_ID="$GAME_C_ID" python3 - <<'PY'
import concurrent.futures
import json
import os
import urllib.error
import urllib.request

base = os.environ["BASE_URL"]
game_id = os.environ["GAME_ID"]

def start():
    req = urllib.request.Request(
        f"{base}/api/games/{game_id}/clock/start",
        data=json.dumps({"expected_version": 1}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as response:
            response.read()
            return response.status
    except urllib.error.HTTPError as exc:
        exc.read()
        return exc.code

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    statuses = sorted([f.result() for f in [pool.submit(start), pool.submit(start)]])

print(",".join(str(x) for x in statuses))
PY
)

[ "$CONCURRENT_RESULT" = "200,409" ] \
    && pass "Two same-version controllers produce one 200 and one 409" \
    || fail "Concurrent controller statuses unexpected: $CONCURRENT_RESULT"

RAW=$(http_json GET "/api/games/${GAME_C_ID}/clock")
BODY=$(echo "$RAW" | strip_status)
[ "$(json_value "$BODY" "version")" = "2" ] && pass "Concurrent mutation increments version exactly once" || fail "Concurrent version not exactly 2"
[ "$(json_value "$BODY" "status")" = "running" ] && pass "Concurrent final state internally consistent" || fail "Concurrent final state"

# ============================================================
# 14. Multi-Game isolation
# ============================================================
RAW=$(http_json POST "/api/games/${GAME_B_ID}/clock" \
    '{"mode":"count_down","duration_seconds":1200}')
CODE=$(echo "$RAW" | status_from)
BODY=$(echo "$RAW" | strip_status)

[ "$CODE" = "201" ] && pass "Game B independent clock created" || fail "Game B clock creation"
[ "$(json_value "$BODY" "version")" = "1" ] && pass "Game B clock version starts at 1" || fail "Game B initial version"

# Game C is running/version 2. Game B must remain stopped/version 1.
RAW=$(http_json GET "/api/games/${GAME_B_ID}/clock")
BODY=$(echo "$RAW" | strip_status)
[ "$(json_value "$BODY" "status")" = "stopped" ] && pass "Game A/C mutations do not alter Game B status" || fail "Game isolation status"
[ "$(json_value "$BODY" "version")" = "1" ] && pass "Game A/C mutations do not alter Game B version" || fail "Game isolation version"

# ============================================================
# 15. Persistence regression
# ============================================================
echo ""
echo "========================================"
echo "Running M8-A persistence regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m8a.sh
M8A_RC=$?
set -e

[ "$M8A_RC" -eq 0 ] \
    && pass "M8-A persistence regression passed" \
    || fail "M8-A persistence regression failed"

# ============================================================
# 16. M7 full regression
# ============================================================
echo ""
echo "========================================"
echo "Running M7 full regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m7.sh
M7_RC=$?
set -e

[ "$M7_RC" -eq 0 ] \
    && pass "M7 full regression passed" \
    || fail "M7 full regression failed"

# ============================================================
# Summary
# ============================================================
echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
    echo "M8-B VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M8-B VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi
