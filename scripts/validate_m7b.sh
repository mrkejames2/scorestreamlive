#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

URL="localhost:8000"
BASE_URL="${BASE_URL:-http://$URL}"

TS=$(date +%s)
PREFIX="M7B-VALIDATION-${TS}"

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

# Helper: POST and capture both body and status code in ONE request
post_json() {
    local path="$1"
    local payload="$2"
    # -w appends HTTP_STATUS:code after body; we split on that delimiter
    local raw
    raw=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${BASE_URL}${path}" -H "Content-Type: application/json" -d "$payload")
    local body
    body=$(echo "$raw" | sed '/HTTP_STATUS:/d')
    local code
    code=$(echo "$raw" | grep "HTTP_STATUS:" | cut -d: -f2)
    echo "${code}|${body}"
}

rest_get() {
    local path="$1"
    curl -s "${BASE_URL}${path}"
}

rest_patch() {
    local path="$1"
    local payload="$2"
    curl -s -X PATCH "${BASE_URL}${path}" -H "Content-Type: application/json" -d "$payload"
}

echo "========================================"
echo "ScoreStreamLive M7-B Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

# ============================================================
# 1. Health
# ============================================================
check_http "/health/live" "200" "health/live"
check_http "/health/ready" "200" "health/ready"
check_http "/info" "200" "info"

# ============================================================
# 2. M7-A Regression — Game scores initialized, PATCH protected
# ============================================================
TEAM_A=$(rest_get "$(curl -s -X POST "${BASE_URL}/api/teams" -H "Content-Type: application/json" -d "{\"name\":\"${PREFIX}-TEAM-A\",\"short_name\":\"TA\"}" | python3 -c "import sys,json; print('/api/teams/' + json.load(sys.stdin)['id'])" 2>/dev/null)")
# Actually, simpler: create and capture IDs inline
TEAM_A_RAW=$(curl -s -X POST "${BASE_URL}/api/teams" -H "Content-Type: application/json" -d "{\"name\":\"${PREFIX}-TEAM-A\",\"short_name\":\"TA\"}")
TEAM_A_ID=$(echo "$TEAM_A_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

TEAM_B_RAW=$(curl -s -X POST "${BASE_URL}/api/teams" -H "Content-Type: application/json" -d "{\"name\":\"${PREFIX}-TEAM-B\",\"short_name\":\"TB\"}")
TEAM_B_ID=$(echo "$TEAM_B_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

GAME_RAW=$(curl -s -X POST "${BASE_URL}/api/games" -H "Content-Type: application/json" -d "{\"name\":\"${PREFIX}-GAME\",\"home_team_id\":\"${TEAM_A_ID}\",\"away_team_id\":\"${TEAM_B_ID}\"}")
GAME_ID=$(echo "$GAME_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

HOME_0=$(echo "$GAME_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
AWAY_0=$(echo "$GAME_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['away_score'])")
[ "$HOME_0" = "0" ] && pass "M7-A regression: new game home_score 0" || fail "M7-A regression: new game home_score not 0 (got $HOME_0)"
[ "$AWAY_0" = "0" ] && pass "M7-A regression: new game away_score 0" || fail "M7-A regression: new game away_score not 0 (got $AWAY_0)"

# PATCH score mutation — score must remain unchanged
rest_patch "/api/games/${GAME_ID}" "{\"home_score\":99}" >/dev/null
GAME_PATCHED=$(rest_get "/api/games/${GAME_ID}")
PATCH_HOME=$(echo "$GAME_PATCHED" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
[ "$PATCH_HOME" = "0" ] && pass "M7-A regression: PATCH home_score ignored" || fail "M7-A regression: PATCH home_score mutated (got $PATCH_HOME)"

# ============================================================
# 3. Home Goal — SINGLE POST
# ============================================================
HOME_GOAL_RESULT=$(post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_A_ID}\",\"player_id\":null,\"event_type\":\"goal\"}")
HOME_GOAL_CODE=$(echo "$HOME_GOAL_RESULT" | cut -d'|' -f1)
HOME_GOAL_BODY=$(echo "$HOME_GOAL_RESULT" | cut -d'|' -f2-)

[ "$HOME_GOAL_CODE" = "201" ] && pass "Home goal returns 201" || fail "Home goal did not return 201 (got $HOME_GOAL_CODE)"

HOME_GOAL_ID=$(echo "$HOME_GOAL_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)
[ -n "$HOME_GOAL_ID" ] && pass "Home goal event has id" || fail "Home goal event missing id"

GAME_AFTER_HOME=$(rest_get "/api/games/${GAME_ID}")
HOME_SCORE_1=$(echo "$GAME_AFTER_HOME" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
AWAY_SCORE_0=$(echo "$GAME_AFTER_HOME" | python3 -c "import sys,json; print(json.load(sys.stdin)['away_score'])")
[ "$HOME_SCORE_1" = "1" ] && pass "Home goal increments home_score to 1" || fail "Home goal home_score is $HOME_SCORE_1"
[ "$AWAY_SCORE_0" = "0" ] && pass "Home goal does not affect away_score" || fail "Home goal away_score is $AWAY_SCORE_0"

# ============================================================
# 4. Away Goal — SINGLE POST
# ============================================================
AWAY_GOAL_RESULT=$(post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_B_ID}\",\"player_id\":null,\"event_type\":\"goal\"}")
AWAY_GOAL_CODE=$(echo "$AWAY_GOAL_RESULT" | cut -d'|' -f1)
AWAY_GOAL_BODY=$(echo "$AWAY_GOAL_RESULT" | cut -d'|' -f2-)

[ "$AWAY_GOAL_CODE" = "201" ] && pass "Away goal returns 201" || fail "Away goal did not return 201 (got $AWAY_GOAL_CODE)"

GAME_AFTER_AWAY=$(rest_get "/api/games/${GAME_ID}")
HOME_SCORE_1B=$(echo "$GAME_AFTER_AWAY" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
AWAY_SCORE_1=$(echo "$GAME_AFTER_AWAY" | python3 -c "import sys,json; print(json.load(sys.stdin)['away_score'])")
[ "$HOME_SCORE_1B" = "1" ] && pass "Away goal preserves home_score" || fail "Away goal home_score is $HOME_SCORE_1B"
[ "$AWAY_SCORE_1" = "1" ] && pass "Away goal increments away_score to 1" || fail "Away goal away_score is $AWAY_SCORE_1"

# ============================================================
# 5. Multiple Goals — accumulate
# ============================================================
post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_A_ID}\",\"player_id\":null,\"event_type\":\"goal\"}" >/dev/null
post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_A_ID}\",\"player_id\":null,\"event_type\":\"goal\"}" >/dev/null
post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_B_ID}\",\"player_id\":null,\"event_type\":\"goal\"}" >/dev/null

GAME_MULTI=$(rest_get "/api/games/${GAME_ID}")
HOME_MULTI=$(echo "$GAME_MULTI" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
AWAY_MULTI=$(echo "$GAME_MULTI" | python3 -c "import sys,json; print(json.load(sys.stdin)['away_score'])")
[ "$HOME_MULTI" = "3" ] && pass "Multiple goals: home_score 3" || fail "Multiple goals: home_score is $HOME_MULTI"
[ "$AWAY_MULTI" = "2" ] && pass "Multiple goals: away_score 2" || fail "Multiple goals: away_score is $AWAY_MULTI"

# ============================================================
# 6. Null Player Goal
# ============================================================
NULL_PLAYER_RESULT=$(post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_A_ID}\",\"player_id\":null,\"event_type\":\"goal\"}")
NULL_PLAYER_CODE=$(echo "$NULL_PLAYER_RESULT" | cut -d'|' -f1)
NULL_PLAYER_BODY=$(echo "$NULL_PLAYER_RESULT" | cut -d'|' -f2-)

[ "$NULL_PLAYER_CODE" = "201" ] && pass "Null player goal returns 201" || fail "Null player goal did not return 201 (got $NULL_PLAYER_CODE)"

NULL_PID=$(echo "$NULL_PLAYER_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print('NULL' if d.get('player_id') is None else d.get('player_id'))")
[ "$NULL_PID" = "NULL" ] && pass "Null player_id accepted" || fail "Null player_id not accepted (got $NULL_PID)"

# ============================================================
# 7. Valid Player Goal — SINGLE POST
# ============================================================
PLAYER_RAW=$(curl -s -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "{\"team_id\":\"${TEAM_A_ID}\",\"first_name\":\"Scorer\",\"last_name\":\"Player\",\"jersey_number\":9}")
PLAYER_ID=$(echo "$PLAYER_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

VALID_GOAL_RESULT=$(post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_A_ID}\",\"player_id\":\"${PLAYER_ID}\",\"event_type\":\"goal\"}")
VALID_GOAL_CODE=$(echo "$VALID_GOAL_RESULT" | cut -d'|' -f1)
VALID_GOAL_BODY=$(echo "$VALID_GOAL_RESULT" | cut -d'|' -f2-)

[ "$VALID_GOAL_CODE" = "201" ] && pass "Valid player goal returns 201" || fail "Valid player goal did not return 201 (got $VALID_GOAL_CODE)"

VALID_PID=$(echo "$VALID_GOAL_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['player_id'])")
[ "$VALID_PID" = "$PLAYER_ID" ] && pass "Valid player goal has correct player_id" || fail "Valid player goal player_id mismatch"

# ============================================================
# 8. Wrong Team
# ============================================================
TEAM_C_RAW=$(curl -s -X POST "${BASE_URL}/api/teams" -H "Content-Type: application/json" -d "{\"name\":\"${PREFIX}-TEAM-C\",\"short_name\":\"TC\"}")
TEAM_C_ID=$(echo "$TEAM_C_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

GAME_BEFORE_WRONG=$(rest_get "/api/games/${GAME_ID}")
HOME_BEFORE_WRONG=$(echo "$GAME_BEFORE_WRONG" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
EVENTS_BEFORE_WRONG=$(rest_get "/api/games/${GAME_ID}/scoring-events" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

WRONG_TEAM_RESULT=$(post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_C_ID}\",\"player_id\":null,\"event_type\":\"goal\"}")
WRONG_TEAM_CODE=$(echo "$WRONG_TEAM_RESULT" | cut -d'|' -f1)
[ "$WRONG_TEAM_CODE" = "422" ] && pass "Wrong team returns 422" || fail "Wrong team did not return 422 (got $WRONG_TEAM_CODE)"

GAME_AFTER_WRONG=$(rest_get "/api/games/${GAME_ID}")
HOME_AFTER_WRONG=$(echo "$GAME_AFTER_WRONG" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
EVENTS_AFTER_WRONG=$(rest_get "/api/games/${GAME_ID}/scoring-events" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
[ "$HOME_AFTER_WRONG" = "$HOME_BEFORE_WRONG" ] && pass "Wrong team: score unchanged" || fail "Wrong team: score changed from $HOME_BEFORE_WRONG to $HOME_AFTER_WRONG"
[ "$EVENTS_AFTER_WRONG" = "$EVENTS_BEFORE_WRONG" ] && pass "Wrong team: no event added" || fail "Wrong team: events changed from $EVENTS_BEFORE_WRONG to $EVENTS_AFTER_WRONG"

# ============================================================
# 9. Missing Player
# ============================================================
GAME_BEFORE_MISS=$(rest_get "/api/games/${GAME_ID}")
HOME_BEFORE_MISS=$(echo "$GAME_BEFORE_MISS" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
EVENTS_BEFORE_MISS=$(rest_get "/api/games/${GAME_ID}/scoring-events" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

MISS_PLAYER_RESULT=$(post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_A_ID}\",\"player_id\":\"00000000-0000-0000-0000-000000000000\",\"event_type\":\"goal\"}")
MISS_PLAYER_CODE=$(echo "$MISS_PLAYER_RESULT" | cut -d'|' -f1)
[ "$MISS_PLAYER_CODE" = "422" ] && pass "Missing player returns 422" || fail "Missing player did not return 422 (got $MISS_PLAYER_CODE)"

GAME_AFTER_MISS=$(rest_get "/api/games/${GAME_ID}")
HOME_AFTER_MISS=$(echo "$GAME_AFTER_MISS" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
EVENTS_AFTER_MISS=$(rest_get "/api/games/${GAME_ID}/scoring-events" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
[ "$HOME_AFTER_MISS" = "$HOME_BEFORE_MISS" ] && pass "Missing player: score unchanged" || fail "Missing player: score changed"
[ "$EVENTS_AFTER_MISS" = "$EVENTS_BEFORE_MISS" ] && pass "Missing player: no event added" || fail "Missing player: event added"

# ============================================================
# 10. Wrong-Team Player
# ============================================================
PLAYER_B_RAW=$(curl -s -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "{\"team_id\":\"${TEAM_B_ID}\",\"first_name\":\"Wrong\",\"last_name\":\"Team\",\"jersey_number\":5}")
PLAYER_B_ID=$(echo "$PLAYER_B_RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

GAME_BEFORE_WTP=$(rest_get "/api/games/${GAME_ID}")
HOME_BEFORE_WTP=$(echo "$GAME_BEFORE_WTP" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
EVENTS_BEFORE_WTP=$(rest_get "/api/games/${GAME_ID}/scoring-events" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

WTP_RESULT=$(post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_A_ID}\",\"player_id\":\"${PLAYER_B_ID}\",\"event_type\":\"goal\"}")
WTP_CODE=$(echo "$WTP_RESULT" | cut -d'|' -f1)
[ "$WTP_CODE" = "422" ] && pass "Wrong-team player returns 422" || fail "Wrong-team player did not return 422 (got $WTP_CODE)"

GAME_AFTER_WTP=$(rest_get "/api/games/${GAME_ID}")
HOME_AFTER_WTP=$(echo "$GAME_AFTER_WTP" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
EVENTS_AFTER_WTP=$(rest_get "/api/games/${GAME_ID}/scoring-events" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
[ "$HOME_AFTER_WTP" = "$HOME_BEFORE_WTP" ] && pass "Wrong-team player: score unchanged" || fail "Wrong-team player: score changed"
[ "$EVENTS_AFTER_WTP" = "$EVENTS_BEFORE_WTP" ] && pass "Wrong-team player: no event added" || fail "Wrong-team player: event added"

# ============================================================
# 11. Invalid Event Type
# ============================================================
GAME_BEFORE_EVT=$(rest_get "/api/games/${GAME_ID}")
HOME_BEFORE_EVT=$(echo "$GAME_BEFORE_EVT" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
EVENTS_BEFORE_EVT=$(rest_get "/api/games/${GAME_ID}/scoring-events" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

BAD_EVT_RESULT=$(post_json "/api/scoring-events" "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_A_ID}\",\"player_id\":null,\"event_type\":\"penalty\"}")
BAD_EVT_CODE=$(echo "$BAD_EVT_RESULT" | cut -d'|' -f1)
[ "$BAD_EVT_CODE" = "422" ] && pass "Invalid event_type returns 422" || fail "Invalid event_type did not return 422 (got $BAD_EVT_CODE)"

GAME_AFTER_EVT=$(rest_get "/api/games/${GAME_ID}")
HOME_AFTER_EVT=$(echo "$GAME_AFTER_EVT" | python3 -c "import sys,json; print(json.load(sys.stdin)['home_score'])")
EVENTS_AFTER_EVT=$(rest_get "/api/games/${GAME_ID}/scoring-events" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
[ "$HOME_AFTER_EVT" = "$HOME_BEFORE_EVT" ] && pass "Invalid event_type: score unchanged" || fail "Invalid event_type: score changed"
[ "$EVENTS_AFTER_EVT" = "$EVENTS_BEFORE_EVT" ] && pass "Invalid event_type: no event added" || fail "Invalid event_type: event added"

# ============================================================
# 12. GET Scoring Events
# ============================================================
EVENTS_LIST=$(rest_get "/api/games/${GAME_ID}/scoring-events")
EVENTS_COUNT=$(echo "$EVENTS_LIST" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
[ "$EVENTS_COUNT" = "7" ] && pass "GET scoring events returns 7 events" || fail "GET scoring events count is $EVENTS_COUNT"

# Verify ordering: created_at ASC, id ASC
ORDER_OK=$(echo "$EVENTS_LIST" | python3 -c "
import sys, json
events = json.load(sys.stdin)
ok = all(
    (events[i]['created_at'], str(events[i]['id'])) <= (events[i+1]['created_at'], str(events[i+1]['id']))
    for i in range(len(events)-1)
)
print('OK' if ok else 'FAIL')
")
[ "$ORDER_OK" = "OK" ] && pass "Scoring events ordered correctly" || fail "Scoring events ordering incorrect"

# Verify fields on first event
FIRST_EVT=$(echo "$EVENTS_LIST" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)[0]))")
HAS_GAME=$(echo "$FIRST_EVT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('game_id') else 'FAIL')")
HAS_TEAM=$(echo "$FIRST_EVT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('team_id') else 'FAIL')")
HAS_TYPE=$(echo "$FIRST_EVT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('event_type')=='goal' else 'FAIL')")
HAS_CREATED=$(echo "$FIRST_EVT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('created_at') else 'FAIL')")
[ "$HAS_GAME" = "OK" ] && pass "Event has game_id" || fail "Event missing game_id"
[ "$HAS_TEAM" = "OK" ] && pass "Event has team_id" || fail "Event missing team_id"
[ "$HAS_TYPE" = "OK" ] && pass "Event has event_type goal" || fail "Event missing/wrong event_type"
[ "$HAS_CREATED" = "OK" ] && pass "Event has created_at" || fail "Event missing created_at"

# ============================================================
# 13. GET Missing Game History
# ============================================================
MISS_GAME_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/games/00000000-0000-0000-0000-000000000000/scoring-events")
[ "$MISS_GAME_CODE" = "404" ] && pass "Missing game history returns 404" || fail "Missing game history did not return 404 (got $MISS_GAME_CODE)"

# ============================================================
# 14. Concurrency Test
# ============================================================
echo ""
echo "Running concurrency test..."

CONCURRENCY_RESULT=$(python3 - "$BASE_URL" <<'PYEOF'
import sys
import concurrent.futures
import json
import urllib.request
import time

BASE_URL = sys.argv[1]

def rest_post(path, payload):
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, {}

def rest_get(path):
    with urllib.request.urlopen(f"{BASE_URL}{path}") as resp:
        return json.loads(resp.read())

# Create teams and game
home_team = rest_post("/api/teams", {"name": "CONC-HOME", "short_name": "CH"})[1]
away_team = rest_post("/api/teams", {"name": "CONC-AWAY", "short_name": "CA"})[1]
game = rest_post("/api/games", {"name": "CONC-GAME", "home_team_id": home_team["id"], "away_team_id": away_team["id"]})[1]
game_id = game["id"]
home_team_id = home_team["id"]

# Get initial state
initial_game = rest_get(f"/api/games/{game_id}")
initial_home = initial_game["home_score"]
initial_events = len(rest_get(f"/api/games/{game_id}/scoring-events"))

payload = {"game_id": game_id, "team_id": home_team_id, "player_id": None, "event_type": "goal"}

def post_goal():
    return rest_post("/api/scoring-events", payload)[0]

# Fire 10 simultaneous requests
with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
    futures = [executor.submit(post_goal) for _ in range(10)]
    results = [f.result() for f in concurrent.futures.as_completed(futures)]

success_count = results.count(201)

# Get final state
final_game = rest_get(f"/api/games/{game_id}")
final_home = final_game["home_score"]
final_events = len(rest_get(f"/api/games/{game_id}/scoring-events"))

score_delta = final_home - initial_home
event_delta = final_events - initial_events

lost = 0
if score_delta != success_count:
    lost += abs(score_delta - success_count)
if event_delta != success_count:
    lost += abs(event_delta - success_count)

print(f"Requests: 10")
print(f"Successful: {success_count}")
print(f"Score delta: {score_delta}")
print(f"Event delta: {event_delta}")
print(f"Lost increments: {lost}")

if lost == 0 and success_count > 0:
    print("CONCURRENCY_PASS")
else:
    print("CONCURRENCY_FAIL")
PYEOF
)

echo "$CONCURRENCY_RESULT"
if echo "$CONCURRENCY_RESULT" | grep -q "CONCURRENCY_PASS"; then
    pass "Concurrency test: no lost increments"
else
    fail "Concurrency test: increments lost"
fi

# ============================================================
# 15. Socket.IO Negative Check
# ============================================================
echo ""
echo "Running Socket.IO negative check..."

SIO_RESULT=$(sudo docker compose exec -T app python3 - "$BASE_URL" <<'PYEOF'
import sys
import socketio
import urllib.request
import json
import time

BASE_URL = sys.argv[1]

m7_events = []
other_events = []
sio = socketio.Client()

@sio.on("scoring_event:created")
def on_scoring_event_created(data):
    m7_events.append("scoring_event:created")

@sio.on("game:score_updated")
def on_game_score_updated(data):
    m7_events.append("game:score_updated")

@sio.on("team:created")
def on_team_created(data):
    other_events.append("team:created")

@sio.on("connection:ready")
def on_connection_ready(data):
    other_events.append("connection:ready")

def rest_post(path, payload):
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

try:
    sio.connect(BASE_URL, socketio_path="/socket.io", transports=["polling"])
    time.sleep(0.5)

    # Create a scoring event via REST
    team = rest_post("/api/teams", {"name": "SIO-NEG-TEAM", "short_name": "SNT"})
    team_b = rest_post("/api/teams", {"name": "SIO-NEG-TEAM-B", "short_name": "SNB"})
    game = rest_post("/api/games", {"name": "SIO-NEG-GAME", "home_team_id": team["id"], "away_team_id": team_b["id"]})
    rest_post("/api/scoring-events", {"game_id": game["id"], "team_id": team["id"], "player_id": None, "event_type": "goal"})

    time.sleep(1.0)

    if not m7_events:
        print("NO_M7_EVENTS")
    else:
        print(f"UNEXPECTED_M7_EVENTS: {m7_events}")

    # Verify existing Socket.IO still works
    rest_post("/api/teams", {"name": "SIO-VERIFY-TEAM", "short_name": "SVT"})
    time.sleep(0.5)

    if "team:created" in other_events:
        print("EXISTING_EVENTS_WORK")
    else:
        print("EXISTING_EVENTS_BROKEN")

    sio.disconnect()
except Exception as e:
    print(f"SOCKET_IO_ERROR: {e}")
PYEOF
)

echo "$SIO_RESULT"
if echo "$SIO_RESULT" | grep -q "NO_M7_EVENTS"; then
    pass "Socket.IO: no M7 events emitted"
else
    fail "Socket.IO: unexpected M7 events"
fi

if echo "$SIO_RESULT" | grep -q "EXISTING_EVENTS_WORK"; then
    pass "Socket.IO: existing events still work"
else
    fail "Socket.IO: existing events broken"
fi

# ============================================================
# 16. M6 Regression
# ============================================================
echo ""
echo "Running M6 regression..."
if ./scripts/validate_m6.sh >/dev/null 2>&1; then
    pass "M6 regression passed"
else
    fail "M6 regression failed"
fi

# ============================================================
# Summary
# ============================================================
echo "========================================"
if [ $FAIL -eq 0 ]; then
    echo "M7-B VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M7-B VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi