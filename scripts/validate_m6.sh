#!/usr/bin/env bash
set -euo pipefail

#BASE_URL="${BASE_URL:-http://192.168.12.133:8000}"
BASE_URL="${BASE_URL:-https://scorestreamlive.onrender.com}"
TS=$(date +%s)
PREFIX="M6-VALIDATION-${TS}"

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

echo "========================================"
echo "ScoreStreamLive M6 Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

# 1. Health
check_http "/health/live" "200" "health/live"
check_http "/health/ready" "200" "health/ready"
check_http "/info" "200" "info"

# 2. Create Team A
TEAM_A_PAYLOAD="{\"name\":\"${PREFIX}-TEAM-A\",\"short_name\":\"TA\"}"
TEAM_A_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/teams" -H "Content-Type: application/json" -d "$TEAM_A_PAYLOAD")
TEAM_A_ID=$(echo "$TEAM_A_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
if [ -n "$TEAM_A_ID" ]; then
    pass "Team A creation"
else
    fail "Team A creation"
    exit 1
fi

# 3. Get Team A
check_http "/api/teams/${TEAM_A_ID}" "200" "Team A retrieval"

# 4. Update Team A
TEAM_A_PATCH="{\"name\":\"${PREFIX}-TEAM-A-UPDATED\"}"
curl -s -o /dev/null -w "%{http_code}" -X PATCH "${BASE_URL}/api/teams/${TEAM_A_ID}" -H "Content-Type: application/json" -d "$TEAM_A_PATCH" | grep -q "200" && pass "Team A update" || fail "Team A update"

# 5. List Teams
check_http "/api/teams" "200" "Team list"

# 6. Create Team B
TEAM_B_PAYLOAD="{\"name\":\"${PREFIX}-TEAM-B\",\"short_name\":\"TB\"}"
TEAM_B_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/teams" -H "Content-Type: application/json" -d "$TEAM_B_PAYLOAD")
TEAM_B_ID=$(echo "$TEAM_B_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
if [ -n "$TEAM_B_ID" ]; then
    pass "Team B creation"
else
    fail "Team B creation"
    exit 1
fi

# 7. Create Game
GAME_PAYLOAD="{\"name\":\"${PREFIX}-GAME\",\"home_team_id\":\"${TEAM_A_ID}\",\"away_team_id\":\"${TEAM_B_ID}\"}"
GAME_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/games" -H "Content-Type: application/json" -d "$GAME_PAYLOAD")
GAME_ID=$(echo "$GAME_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
if [ -n "$GAME_ID" ]; then
    pass "Game creation"
else
    fail "Game creation"
    exit 1
fi

# 8. Get Game
check_http "/api/games/${GAME_ID}" "200" "Game retrieval"

# 9. Update Game
GAME_PATCH="{\"name\":\"${PREFIX}-GAME-UPDATED\"}"
curl -s -o /dev/null -w "%{http_code}" -X PATCH "${BASE_URL}/api/games/${GAME_ID}" -H "Content-Type: application/json" -d "$GAME_PATCH" | grep -q "200" && pass "Game update" || fail "Game update"

# 10. List Games
check_http "/api/games" "200" "Game list"

# 11. Create Player on Team A
PLAYER_PAYLOAD="{\"team_id\":\"${TEAM_A_ID}\",\"first_name\":\"Validation\",\"last_name\":\"Player\",\"jersey_number\":10}"
PLAYER_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "$PLAYER_PAYLOAD")
PLAYER_ID=$(echo "$PLAYER_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
if [ -n "$PLAYER_ID" ]; then
    pass "Player creation"
else
    fail "Player creation"
    exit 1
fi

# Verify player fields
PLAYER_FN=$(echo "$PLAYER_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['first_name'])")
PLAYER_LN=$(echo "$PLAYER_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['last_name'])")
PLAYER_JN=$(echo "$PLAYER_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['jersey_number'])")
PLAYER_TID=$(echo "$PLAYER_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['team_id'])")

[ "$PLAYER_FN" = "Validation" ] && pass "Player first_name" || fail "Player first_name"
[ "$PLAYER_LN" = "Player" ] && pass "Player last_name" || fail "Player last_name"
[ "$PLAYER_JN" = "10" ] && pass "Player jersey_number" || fail "Player jersey_number"
[ "$PLAYER_TID" = "$TEAM_A_ID" ] && pass "Player team_id" || fail "Player team_id"

# 12. Get Player
check_http "/api/players/${PLAYER_ID}" "200" "Player retrieval"

# 13. Update Player jersey to 11
PLAYER_PATCH_1="{\"jersey_number\":11}"
PLAYER_UPDATED=$(curl -s -X PATCH "${BASE_URL}/api/players/${PLAYER_ID}" -H "Content-Type: application/json" -d "$PLAYER_PATCH_1")
UPDATED_JN=$(echo "$PLAYER_UPDATED" | python3 -c "import sys,json; print(json.load(sys.stdin)['jersey_number'])")
[ "$UPDATED_JN" = "11" ] && pass "Player jersey update" || fail "Player jersey update"

# 14. Clear Player jersey to null
PLAYER_PATCH_2="{\"jersey_number\":null}"
PLAYER_CLEARED=$(curl -s -X PATCH "${BASE_URL}/api/players/${PLAYER_ID}" -H "Content-Type: application/json" -d "$PLAYER_PATCH_2")
CLEARED_JN=$(echo "$PLAYER_CLEARED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['jersey_number'] if d['jersey_number'] is not None else 'NULL')")
[ "$CLEARED_JN" = "NULL" ] && pass "Player jersey clear" || fail "Player jersey clear (got: $CLEARED_JN)"

# 15. Get Team A roster
ROSTER_A=$(curl -s "${BASE_URL}/api/teams/${TEAM_A_ID}/players")
ROSTER_A_COUNT=$(echo "$ROSTER_A" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
[ "$ROSTER_A_COUNT" = "1" ] && pass "Team A roster" || fail "Team A roster (count: $ROSTER_A_COUNT)"

# 16. Create Player on Team B
PLAYER_B_PAYLOAD="{\"team_id\":\"${TEAM_B_ID}\",\"first_name\":\"Other\",\"last_name\":\"Player\",\"jersey_number\":99}"
PLAYER_B_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "$PLAYER_B_PAYLOAD")
PLAYER_B_ID=$(echo "$PLAYER_B_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
if [ -n "$PLAYER_B_ID" ]; then
    pass "Player B creation"
else
    fail "Player B creation"
fi

# 17. Team isolation
ROSTER_A_IDS=$(echo "$ROSTER_A" | python3 -c "import sys,json; print([p['id'] for p in json.load(sys.stdin)])")
ROSTER_B=$(curl -s "${BASE_URL}/api/teams/${TEAM_B_ID}/players")
ROSTER_B_IDS=$(echo "$ROSTER_B" | python3 -c "import sys,json; print([p['id'] for p in json.load(sys.stdin)])")

if echo "$ROSTER_A_IDS" | grep -q "$PLAYER_B_ID"; then
    fail "Team isolation (Team A has Team B player)"
else
    pass "Team isolation A"
fi

if echo "$ROSTER_B_IDS" | grep -q "$PLAYER_ID"; then
    fail "Team isolation (Team B has Team A player)"
else
    pass "Team isolation B"
fi

# 18. Missing Team roster → 404
NONEXISTENT_TEAM="00000000-0000-0000-0000-000000000000"
ROSTER_404=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/teams/${NONEXISTENT_TEAM}/players")
[ "$ROSTER_404" = "404" ] && pass "Missing Team roster 404" || fail "Missing Team roster 404 (got $ROSTER_404)"

# 19. Invalid Team for Player creation → 422
INVALID_PLAYER_PAYLOAD="{\"team_id\":\"${NONEXISTENT_TEAM}\",\"first_name\":\"X\",\"last_name\":\"Y\"}"
INVALID_PLAYER_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "$INVALID_PLAYER_PAYLOAD")
[ "$INVALID_PLAYER_CODE" = "422" ] && pass "Invalid Team rejected" || fail "Invalid Team rejected (got $INVALID_PLAYER_CODE)"

# 20. Missing Player → 404
MISSING_PLAYER="00000000-0000-0000-0000-000000000000"
MP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/players/${MISSING_PLAYER}")
[ "$MP_CODE" = "404" ] && pass "Missing Player 404" || fail "Missing Player 404 (got $MP_CODE)"

# 21. Validation errors
# Blank first_name
BLANK_FN="{\"team_id\":\"${TEAM_A_ID}\",\"first_name\":\"   \",\"last_name\":\"Valid\"}"
BLANK_FN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "$BLANK_FN")
[ "$BLANK_FN_CODE" = "422" ] && pass "Blank first_name rejected" || fail "Blank first_name rejected (got $BLANK_FN_CODE)"

# Blank last_name
BLANK_LN="{\"team_id\":\"${TEAM_A_ID}\",\"first_name\":\"Valid\",\"last_name\":\"   \"}"
BLANK_LN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "$BLANK_LN")
[ "$BLANK_LN_CODE" = "422" ] && pass "Blank last_name rejected" || fail "Blank last_name rejected (got $BLANK_LN_CODE)"

# Invalid jersey -1
NEG_JERSEY="{\"team_id\":\"${TEAM_A_ID}\",\"first_name\":\"Valid\",\"last_name\":\"Valid\",\"jersey_number\":-1}"
NEG_JERSEY_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "$NEG_JERSEY")
[ "$NEG_JERSEY_CODE" = "422" ] && pass "Negative jersey rejected" || fail "Negative jersey rejected (got $NEG_JERSEY_CODE)"

# Invalid jersey 1000
BIG_JERSEY="{\"team_id\":\"${TEAM_A_ID}\",\"first_name\":\"Valid\",\"last_name\":\"Valid\",\"jersey_number\":1000}"
BIG_JERSEY_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "$BIG_JERSEY")
[ "$BIG_JERSEY_CODE" = "422" ] && pass "Large jersey rejected" || fail "Large jersey rejected (got $BIG_JERSEY_CODE)"

# 22. Roster ordering validation
# Create multiple players on a dedicated ordering test team
ORDER_TEAM_PAYLOAD="{\"name\":\"${PREFIX}-ORDER-TEAM\",\"short_name\":\"ORD\"}"
ORDER_TEAM_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/teams" -H "Content-Type: application/json" -d "$ORDER_TEAM_PAYLOAD")
ORDER_TEAM_ID=$(echo "$ORDER_TEAM_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
if [ -z "$ORDER_TEAM_ID" ]; then
    fail "Order test team creation"
    exit 1
fi
pass "Order test team creation"

# Create players in deliberately non-ordered sequence:
# P1: jersey=null, last=Zebra, first=A
# P2: jersey=10, last=Alpha, first=B
# P3: jersey=10, last=Alpha, first=A
# P4: jersey=5, last=Beta, first=C
# P5: jersey=null, last=Apple, first=D

P1=$(curl -s -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "{\"team_id\":\"${ORDER_TEAM_ID}\",\"first_name\":\"A\",\"last_name\":\"Zebra\"}")
P2=$(curl -s -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "{\"team_id\":\"${ORDER_TEAM_ID}\",\"first_name\":\"B\",\"last_name\":\"Alpha\",\"jersey_number\":10}")
P3=$(curl -s -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "{\"team_id\":\"${ORDER_TEAM_ID}\",\"first_name\":\"A\",\"last_name\":\"Alpha\",\"jersey_number\":10}")
P4=$(curl -s -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "{\"team_id\":\"${ORDER_TEAM_ID}\",\"first_name\":\"C\",\"last_name\":\"Beta\",\"jersey_number\":5}")
P5=$(curl -s -X POST "${BASE_URL}/api/players" -H "Content-Type: application/json" -d "{\"team_id\":\"${ORDER_TEAM_ID}\",\"first_name\":\"D\",\"last_name\":\"Apple\"}")

# Fetch roster and verify order
ROSTER_ORDER=$(curl -s "${BASE_URL}/api/teams/${ORDER_TEAM_ID}/players")
ROSTER_NAMES=$(echo "$ROSTER_ORDER" | python3 -c "import sys,json; print([p['last_name'] for p in json.load(sys.stdin)])")

# Expected order: Beta(5), Alpha(10,A), Alpha(10,B), Apple(null), Zebra(null)
if echo "$ROSTER_NAMES" | grep -q "\['Beta', 'Alpha', 'Alpha', 'Apple', 'Zebra'\]"; then
    pass "Roster ordering correct"
else
    fail "Roster ordering incorrect (got: $ROSTER_NAMES)"
fi

# 23. Socket.IO Regression + M6 Event Tests (runs inside app container)
echo ""
echo "========================================"
echo "Socket.IO Regression + M6 Event Tests"
echo "========================================"

SIO_URL="${BASE_URL}"

while IFS= read -r line; do
    echo "$line"
    if [[ "$line" == "[PASS]"* ]]; then
        PASS=$((PASS + 1))
    elif [[ "$line" == "[FAIL]"* ]]; then
        FAIL=$((FAIL + 1))
    fi
done < <(sudo docker compose exec -T app python3 - "$SIO_URL" <<'PYEOF'
import sys
import socketio
import urllib.request
import json
import time

BASE_URL = sys.argv[1] if len(sys.argv) > 1 else "https://scorestreamlive.onrender.com"

events_received = []
sio = socketio.Client()

@sio.event
def connect():
    print("[PASS] Socket.IO connected")

@sio.event
def disconnect():
    print("[PASS] Socket.IO disconnected")

@sio.on("connection:ready")
def on_connection_ready(data):
    events_received.append(("connection:ready", data))

@sio.on("server:pong")
def on_server_pong(data):
    events_received.append(("server:pong", data))

@sio.on("team:created")
def on_team_created(data):
    events_received.append(("team:created", data))

@sio.on("team:updated")
def on_team_updated(data):
    events_received.append(("team:updated", data))

@sio.on("game:created")
def on_game_created(data):
    events_received.append(("game:created", data))

@sio.on("game:updated")
def on_game_updated(data):
    events_received.append(("game:updated", data))

@sio.on("player:created")
def on_player_created(data):
    events_received.append(("player:created", data))

@sio.on("player:updated")
def on_player_updated(data):
    events_received.append(("player:updated", data))

@sio.on("roster:updated")
def on_roster_updated(data):
    events_received.append(("roster:updated", data))

def rest_post(path, payload):
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

def rest_patch(path, payload):
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="PATCH"
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

def wait_for_event(event_name, timeout=5):
    start = time.time()
    while time.time() - start < timeout:
        for e in events_received:
            if e[0] == event_name:
                return True
        time.sleep(0.1)
    return False

def event_received(event_name):
    return any(e[0] == event_name for e in events_received)

def get_event_payload(event_name):
    for e in events_received:
        if e[0] == event_name:
            return e[1]
    return None

def get_event_index(event_name):
    for i, e in enumerate(events_received):
        if e[0] == event_name:
            return i
    return -1

try:
    sio.connect(BASE_URL, socketio_path="/socket.io", transports=["polling"])
    time.sleep(0.5)

    if event_received("connection:ready"):
        print("[PASS] connection:ready received")
    else:
        print("[FAIL] connection:ready not received")
        sys.exit(1)

    # Ping with callback (ack)
    ack = sio.call("client:ping", {"timestamp": "2026-01-01T00:00:00Z"}, timeout=5)
    if ack and ack.get("status") == "acknowledged":
        print("[PASS] client:ping acknowledged")
    else:
        print("[FAIL] client:ping not acknowledged")
        sys.exit(1)

    if event_received("server:pong"):
        print("[PASS] server:pong event received")
    else:
        print("[FAIL] server:pong event not received")
        sys.exit(1)

    # Create Team → team:created
    team = rest_post("/api/teams", {"name": "SIO-Test-Team", "short_name": "STT"})
    if wait_for_event("team:created"):
        print("[PASS] team:created received")
    else:
        print("[FAIL] team:created not received")
        sys.exit(1)

    # Update Team → team:updated
    rest_patch(f"/api/teams/{team['id']}", {"name": "SIO-Test-Team-Updated"})
    if wait_for_event("team:updated"):
        print("[PASS] team:updated received")
    else:
        print("[FAIL] team:updated not received")
        sys.exit(1)

    # Create Game → game:created
    team_b = rest_post("/api/teams", {"name": "SIO-Test-Team-B", "short_name": "STB"})
    game = rest_post("/api/games", {"name": "SIO-Test-Game", "home_team_id": team["id"], "away_team_id": team_b["id"]})
    if wait_for_event("game:created"):
        print("[PASS] game:created received")
    else:
        print("[FAIL] game:created not received")
        sys.exit(1)

    # Update Game → game:updated
    rest_patch(f"/api/games/{game['id']}", {"name": "SIO-Test-Game-Updated"})
    if wait_for_event("game:updated"):
        print("[PASS] game:updated received")
    else:
        print("[FAIL] game:updated not received")
        sys.exit(1)

    # M6-C: Player/Roster Event Tests
    player = rest_post("/api/players", {
        "team_id": team["id"],
        "first_name": "SocketIO",
        "last_name": "TestPlayer",
        "jersey_number": 42
    })

    if wait_for_event("player:created"):
        print("[PASS] player:created received")
    else:
        print("[FAIL] player:created not received")
        sys.exit(1)

    pc_payload = get_event_payload("player:created")
    if pc_payload and all(k in pc_payload for k in ("id", "team_id", "first_name", "last_name", "jersey_number", "created_at", "updated_at")):
        print("[PASS] player:created payload complete")
    else:
        print("[FAIL] player:created payload incomplete")
        sys.exit(1)

    if pc_payload and pc_payload.get("first_name") == "SocketIO" and pc_payload.get("last_name") == "TestPlayer" and pc_payload.get("jersey_number") == 42:
        print("[PASS] player:created payload values correct")
    else:
        print("[FAIL] player:created payload values incorrect")
        sys.exit(1)

    if wait_for_event("roster:updated"):
        print("[PASS] roster:updated received after player:created")
    else:
        print("[FAIL] roster:updated not received after player:created")
        sys.exit(1)

    ru_payload = get_event_payload("roster:updated")
    if ru_payload and ru_payload.get("team_id") == str(team["id"]):
        print("[PASS] roster:updated team_id correct")
    else:
        print("[FAIL] roster:updated team_id incorrect")
        sys.exit(1)

    # Verify ordering: player:created before roster:updated
    pc_idx = get_event_index("player:created")
    ru_idx = get_event_index("roster:updated")
    if pc_idx >= 0 and ru_idx >= 0 and pc_idx < ru_idx:
        print("[PASS] player:created before roster:updated ordering")
    else:
        print("[FAIL] player:created before roster:updated ordering violated")
        sys.exit(1)

    # Update Player → player:updated + roster:updated
    events_received.clear()
    rest_patch(f"/api/players/{player['id']}", {"jersey_number": 99})

    if wait_for_event("player:updated"):
        print("[PASS] player:updated received")
    else:
        print("[FAIL] player:updated not received")
        sys.exit(1)

    pu_payload = get_event_payload("player:updated")
    if pu_payload and pu_payload.get("jersey_number") == 99:
        print("[PASS] player:updated payload reflects new state")
    else:
        print("[FAIL] player:updated payload does not reflect new state")
        sys.exit(1)

    if wait_for_event("roster:updated"):
        print("[PASS] roster:updated received after player:updated")
    else:
        print("[FAIL] roster:updated not received after player:updated")
        sys.exit(1)

    # Verify ordering: player:updated before roster:updated
    pu_idx = get_event_index("player:updated")
    ru2_idx = get_event_index("roster:updated")
    if pu_idx >= 0 and ru2_idx >= 0 and pu_idx < ru2_idx:
        print("[PASS] player:updated before roster:updated ordering")
    else:
        print("[FAIL] player:updated before roster:updated ordering violated")
        sys.exit(1)

    # Failed Player creation → NO player/roster events
    events_received.clear()
    try:
        req = urllib.request.Request(
            f"{BASE_URL}/api/players",
            data=json.dumps({"team_id": "00000000-0000-0000-0000-000000000000", "first_name": "X", "last_name": "Y"}).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req) as resp:
            pass
    except urllib.error.HTTPError as e:
        if e.code == 422:
            pass
        else:
            print(f"[FAIL] Unexpected HTTP error code: {e.code}")
            sys.exit(1)

    time.sleep(0.5)
    bad = [e for e in events_received if e[0] in ("player:created", "roster:updated")]
    if not bad:
        print("[PASS] No player:created or roster:updated for failed creation")
    else:
        print(f"[FAIL] Events emitted for failed creation: {bad}")
        sys.exit(1)

    # Disconnect/reconnect
    sio.disconnect()
    time.sleep(0.5)
    sio.connect(BASE_URL, socketio_path="/socket.io", transports=["polling"])
    time.sleep(0.5)
    if event_received("connection:ready"):
        print("[PASS] Reconnect successful")
    else:
        print("[FAIL] Reconnect failed")
        sys.exit(1)

    sio.disconnect()
    print("[PASS] Socket.IO regression + M6 events complete")
    sys.exit(0)

except Exception as e:
    print(f"[FAIL] Socket.IO test error: {e}")
    sys.exit(1)
PYEOF
)

echo "========================================"
if [ $FAIL -eq 0 ]; then
    echo "M6 REST + SOCKET.IO VALIDATION PASSED"
    echo "Passed: $PASS  Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M6 REST + SOCKET.IO VALIDATION FAILED"
    echo "Passed: $PASS  Failed: $FAIL"
    echo "========================================"
    exit 1
fi