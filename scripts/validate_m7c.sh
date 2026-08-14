#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"

TS=$(date +%s)
PREFIX="M7C-VALIDATION-${TS}"

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
echo "ScoreStreamLive M7-C Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

# ============================================================
# 1. Health
# ============================================================
check_http "/health/live" "200" "health/live"
check_http "/health/ready" "200" "health/ready"
check_http "/info" "200" "info"

# ============================================================
# 2. M7-A Regression
# ============================================================
TEAM_A_RAW=$(curl -s -X POST "${BASE_URL}/api/teams" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${PREFIX}-TEAM-A\",\"short_name\":\"TA\"}")

TEAM_A_ID=$(echo "$TEAM_A_RAW" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['id'])")

TEAM_B_RAW=$(curl -s -X POST "${BASE_URL}/api/teams" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${PREFIX}-TEAM-B\",\"short_name\":\"TB\"}")

TEAM_B_ID=$(echo "$TEAM_B_RAW" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['id'])")

GAME_RAW=$(curl -s -X POST "${BASE_URL}/api/games" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${PREFIX}-GAME\",\"home_team_id\":\"${TEAM_A_ID}\",\"away_team_id\":\"${TEAM_B_ID}\"}")

GAME_ID=$(echo "$GAME_RAW" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['id'])")

HOME_0=$(echo "$GAME_RAW" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['home_score'])")

AWAY_0=$(echo "$GAME_RAW" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['away_score'])")

[ "$HOME_0" = "0" ] \
    && pass "M7-A regression: home_score 0" \
    || fail "M7-A regression: home_score not 0"

[ "$AWAY_0" = "0" ] \
    && pass "M7-A regression: away_score 0" \
    || fail "M7-A regression: away_score not 0"

# ============================================================
# 3. M7-B Regression
#
# We validate the important M7-B behavior directly here.
# We intentionally do NOT make validate_m7b.sh a final M7-C gate,
# because that older checkpoint script may contain the old expectation
# that M7 Socket.IO events do not yet exist.
# ============================================================
HOME_GOAL_RAW=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    -X POST "${BASE_URL}/api/scoring-events" \
    -H "Content-Type: application/json" \
    -d "{\"game_id\":\"${GAME_ID}\",\"team_id\":\"${TEAM_A_ID}\",\"player_id\":null,\"event_type\":\"goal\"}")

HOME_GOAL_CODE=$(echo "$HOME_GOAL_RAW" | grep "HTTP_STATUS:" | cut -d: -f2)

[ "$HOME_GOAL_CODE" = "201" ] \
    && pass "M7-B regression: home goal 201" \
    || fail "M7-B regression: home goal not 201"

GAME_AFTER=$(curl -s "${BASE_URL}/api/games/${GAME_ID}")

HOME_1=$(echo "$GAME_AFTER" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['home_score'])")

[ "$HOME_1" = "1" ] \
    && pass "M7-B regression: score incremented" \
    || fail "M7-B regression: score not incremented"

EVENTS_LIST=$(curl -s "${BASE_URL}/api/games/${GAME_ID}/scoring-events")

EVENTS_COUNT=$(echo "$EVENTS_LIST" | python3 -c \
    "import sys,json; print(len(json.load(sys.stdin)))")

[ "$EVENTS_COUNT" = "1" ] \
    && pass "M7-B regression: event persisted" \
    || fail "M7-B regression: event not persisted"

# ============================================================
# 4. Socket.IO M7-C Tests
# ============================================================
echo ""
echo "========================================"
echo "Socket.IO M7-C Event Tests"
echo "========================================"

PY_TEST_FILE=$(mktemp)
SIO_OUTPUT=$(mktemp)

cat > "$PY_TEST_FILE" << 'PYTHON_EOF'
import concurrent.futures
import json
import sys
import time
import urllib.error
import urllib.request

import socketio

BASE_URL = sys.argv[1]

# Every Socket.IO event goes into this list.
events_received = []

# M7 events are also mirrored here so concurrency tests can count them.
m7_events = []

sio = socketio.Client()


@sio.event
def connect():
    pass


@sio.event
def disconnect():
    pass


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


@sio.on("scoring_event:created")
def on_scoring_event_created(data):
    m7_events.append(("scoring_event:created", data))
    events_received.append(("scoring_event:created", data))


@sio.on("game:score_updated")
def on_game_score_updated(data):
    m7_events.append(("game:score_updated", data))
    events_received.append(("game:score_updated", data))


def rest_post(path, payload):
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def rest_patch(path, payload):
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="PATCH",
    )

    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def rest_get(path):
    with urllib.request.urlopen(f"{BASE_URL}{path}") as resp:
        return json.loads(resp.read())


def wait_for_event(event_name, timeout=5):
    start = time.time()

    while time.time() - start < timeout:
        if any(event[0] == event_name for event in events_received):
            return True

        time.sleep(0.1)

    return False


def event_received(event_name):
    return any(event[0] == event_name for event in events_received)


def get_event_payload(event_name):
    for received_name, payload in events_received:
        if received_name == event_name:
            return payload

    return None


def get_event_index(event_name):
    for index, event in enumerate(events_received):
        if event[0] == event_name:
            return index

    return -1


def clear_events():
    events_received.clear()
    m7_events.clear()


results = {
    "pass": 0,
    "fail": 0,
}


def check(label, condition):
    if condition:
        print(f"[PASS] {label}", flush=True)
        results["pass"] += 1
    else:
        print(f"[FAIL] {label}", flush=True)
        results["fail"] += 1


# ============================================================
# Initial Socket.IO Connection
# ============================================================
sio.connect(
    BASE_URL,
    socketio_path="/socket.io",
    transports=["polling"],
)

time.sleep(0.5)

check(
    "Socket.IO connected",
    sio.connected,
)

check(
    "connection:ready received",
    wait_for_event("connection:ready"),
)

# ============================================================
# client:ping acknowledgement
# ============================================================
ack = sio.call(
    "client:ping",
    {
        "timestamp": "2026-01-01T00:00:00Z",
    },
    timeout=5,
)

check(
    "client:ping acknowledged",
    bool(
        ack
        and ack.get("status") == "acknowledged"
    ),
)

check(
    "server:pong event received",
    wait_for_event("server:pong"),
)

# ============================================================
# Existing M3-M6 Events
# ============================================================
clear_events()

team = rest_post(
    "/api/teams",
    {
        "name": "SIO-EXIST-TEAM",
        "short_name": "SET",
    },
)

check(
    "team:created received",
    wait_for_event("team:created"),
)

rest_patch(
    f"/api/teams/{team['id']}",
    {
        "name": "SIO-EXIST-TEAM-UPDATED",
    },
)

check(
    "team:updated received",
    wait_for_event("team:updated"),
)

team_b = rest_post(
    "/api/teams",
    {
        "name": "SIO-EXIST-TEAM-B",
        "short_name": "SEB",
    },
)

game = rest_post(
    "/api/games",
    {
        "name": "SIO-EXIST-GAME",
        "home_team_id": team["id"],
        "away_team_id": team_b["id"],
    },
)

check(
    "game:created received",
    wait_for_event("game:created"),
)

rest_patch(
    f"/api/games/{game['id']}",
    {
        "name": "SIO-EXIST-GAME-UPDATED",
    },
)

check(
    "game:updated received",
    wait_for_event("game:updated"),
)

player = rest_post(
    "/api/players",
    {
        "team_id": team["id"],
        "first_name": "SIO",
        "last_name": "Player",
        "jersey_number": 1,
    },
)

check(
    "player:created received",
    wait_for_event("player:created"),
)

check(
    "roster:updated received",
    wait_for_event("roster:updated"),
)

clear_events()

rest_patch(
    f"/api/players/{player['id']}",
    {
        "jersey_number": 2,
    },
)

check(
    "player:updated received",
    wait_for_event("player:updated"),
)

check(
    "roster:updated received after player update",
    wait_for_event("roster:updated"),
)

# ============================================================
# M7-C: Home Goal
# ============================================================
clear_events()

scoring_game = rest_post(
    "/api/games",
    {
        "name": "SIO-SCORING-GAME",
        "home_team_id": team["id"],
        "away_team_id": team_b["id"],
    },
)

# Remove game:created from the event list before testing score ordering.
clear_events()

home_goal = rest_post(
    "/api/scoring-events",
    {
        "game_id": scoring_game["id"],
        "team_id": team["id"],
        "player_id": None,
        "event_type": "goal",
    },
)

check(
    "scoring_event:created received",
    wait_for_event("scoring_event:created"),
)

check(
    "game:score_updated received",
    wait_for_event("game:score_updated"),
)

# ============================================================
# scoring_event:created Payload
# ============================================================
se_payload = get_event_payload(
    "scoring_event:created"
)

check(
    "scoring_event:created has id",
    bool(
        se_payload
        and "id" in se_payload
    ),
)

check(
    "scoring_event:created has game_id",
    bool(
        se_payload
        and "game_id" in se_payload
    ),
)

check(
    "scoring_event:created has team_id",
    bool(
        se_payload
        and "team_id" in se_payload
    ),
)

check(
    "scoring_event:created has player_id",
    bool(
        se_payload
        and "player_id" in se_payload
    ),
)

check(
    "scoring_event:created has event_type",
    bool(
        se_payload
        and "event_type" in se_payload
    ),
)

check(
    "scoring_event:created has created_at",
    bool(
        se_payload
        and "created_at" in se_payload
    ),
)

if se_payload:
    check(
        "scoring_event:created game_id matches",
        str(scoring_game["id"]) == se_payload["game_id"],
    )

    check(
        "scoring_event:created team_id matches",
        str(team["id"]) == se_payload["team_id"],
    )

    check(
        "scoring_event:created player_id is null",
        se_payload["player_id"] is None,
    )

    check(
        "scoring_event:created event_type is goal",
        se_payload["event_type"] == "goal",
    )

    check(
        "scoring_event:created id matches REST",
        str(home_goal["id"]) == se_payload["id"],
    )

# ============================================================
# game:score_updated Payload
# ============================================================
score_payload = get_event_payload(
    "game:score_updated"
)

check(
    "game:score_updated has game_id",
    bool(
        score_payload
        and "game_id" in score_payload
    ),
)

check(
    "game:score_updated has home_score",
    bool(
        score_payload
        and "home_score" in score_payload
    ),
)

check(
    "game:score_updated has away_score",
    bool(
        score_payload
        and "away_score" in score_payload
    ),
)

if score_payload:
    check(
        "game:score_updated game_id matches",
        str(scoring_game["id"]) == score_payload["game_id"],
    )

    check(
        "game:score_updated home_score is 1",
        score_payload["home_score"] == 1,
    )

    check(
        "game:score_updated away_score is 0",
        score_payload["away_score"] == 0,
    )

# ============================================================
# Compare Socket.IO Score to Authoritative REST Game State
# ============================================================
rest_game = rest_get(
    f"/api/games/{scoring_game['id']}"
)

if score_payload:
    check(
        "game:score_updated matches REST home_score",
        score_payload["home_score"] == rest_game["home_score"],
    )

    check(
        "game:score_updated matches REST away_score",
        score_payload["away_score"] == rest_game["away_score"],
    )

# ============================================================
# Event Ordering
# ============================================================
scoring_index = get_event_index(
    "scoring_event:created"
)

score_index = get_event_index(
    "game:score_updated"
)

check(
    "scoring_event:created before game:score_updated",
    scoring_index >= 0
    and score_index >= 0
    and scoring_index < score_index,
)

# ============================================================
# M7-C: Away Goal
# ============================================================
clear_events()

rest_post(
    "/api/scoring-events",
    {
        "game_id": scoring_game["id"],
        "team_id": team_b["id"],
        "player_id": None,
        "event_type": "goal",
    },
)

check(
    "Away goal: scoring_event:created received",
    wait_for_event("scoring_event:created"),
)

check(
    "Away goal: game:score_updated received",
    wait_for_event("game:score_updated"),
)

away_score_payload = get_event_payload(
    "game:score_updated"
)

if away_score_payload:
    check(
        "Away goal: home_score still 1",
        away_score_payload["home_score"] == 1,
    )

    check(
        "Away goal: away_score is 1",
        away_score_payload["away_score"] == 1,
    )

# ============================================================
# M7-C: Goal With Valid Player
# ============================================================
scorer = rest_post(
    "/api/players",
    {
        "team_id": team["id"],
        "first_name": "Goal",
        "last_name": "Scorer",
        "jersey_number": 99,
    },
)

clear_events()

rest_post(
    "/api/scoring-events",
    {
        "game_id": scoring_game["id"],
        "team_id": team["id"],
        "player_id": scorer["id"],
        "event_type": "goal",
    },
)

check(
    "Player goal: scoring_event:created received",
    wait_for_event("scoring_event:created"),
)

check(
    "Player goal: game:score_updated received",
    wait_for_event("game:score_updated"),
)

player_event = get_event_payload(
    "scoring_event:created"
)

if player_event:
    check(
        "Player goal: player_id matches",
        str(scorer["id"]) == player_event["player_id"],
    )

# ============================================================
# Failed Mutation Helper
# ============================================================
def post_expect_http_error(
    payload,
    expected_code=422,
):
    req = urllib.request.Request(
        f"{BASE_URL}/api/scoring-events",
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req):
            return False

    except urllib.error.HTTPError as exc:
        return exc.code == expected_code


# ============================================================
# Failed Mutation: Wrong Team
# ============================================================
clear_events()

wrong_team_rejected = post_expect_http_error(
    {
        "game_id": str(scoring_game["id"]),
        "team_id": "00000000-0000-0000-0000-000000000000",
        "player_id": None,
        "event_type": "goal",
    }
)

check(
    "Wrong team: request rejected with 422",
    wrong_team_rejected,
)

time.sleep(0.5)

check(
    "Wrong team: no scoring_event:created",
    not event_received("scoring_event:created"),
)

check(
    "Wrong team: no game:score_updated",
    not event_received("game:score_updated"),
)

# ============================================================
# Failed Mutation: Missing Player
# ============================================================
clear_events()

missing_player_rejected = post_expect_http_error(
    {
        "game_id": str(scoring_game["id"]),
        "team_id": str(team["id"]),
        "player_id": "00000000-0000-0000-0000-000000000000",
        "event_type": "goal",
    }
)

check(
    "Missing player: request rejected with 422",
    missing_player_rejected,
)

time.sleep(0.5)

check(
    "Missing player: no scoring_event:created",
    not event_received("scoring_event:created"),
)

check(
    "Missing player: no game:score_updated",
    not event_received("game:score_updated"),
)

# ============================================================
# Failed Mutation: Wrong-Team Player
# ============================================================
wrong_player = rest_post(
    "/api/players",
    {
        "team_id": team_b["id"],
        "first_name": "Wrong",
        "last_name": "Team",
        "jersey_number": 5,
    },
)

clear_events()

wrong_player_rejected = post_expect_http_error(
    {
        "game_id": str(scoring_game["id"]),
        "team_id": str(team["id"]),
        "player_id": str(wrong_player["id"]),
        "event_type": "goal",
    }
)

check(
    "Wrong-team player: request rejected with 422",
    wrong_player_rejected,
)

time.sleep(0.5)

check(
    "Wrong-team player: no scoring_event:created",
    not event_received("scoring_event:created"),
)

check(
    "Wrong-team player: no game:score_updated",
    not event_received("game:score_updated"),
)

# ============================================================
# Failed Mutation: Invalid Event Type
# ============================================================
clear_events()

invalid_type_rejected = post_expect_http_error(
    {
        "game_id": str(scoring_game["id"]),
        "team_id": str(team["id"]),
        "player_id": None,
        "event_type": "penalty",
    }
)

check(
    "Invalid event_type: request rejected with 422",
    invalid_type_rejected,
)

time.sleep(0.5)

check(
    "Invalid event_type: no scoring_event:created",
    not event_received("scoring_event:created"),
)

check(
    "Invalid event_type: no game:score_updated",
    not event_received("game:score_updated"),
)

# ============================================================
# M7-C: Concurrency + Events
# ============================================================
print("")
print(
    "Running concurrency + event test...",
    flush=True,
)

concurrency_game = rest_post(
    "/api/games",
    {
        "name": "SIO-CONC-GAME",
        "home_team_id": team["id"],
        "away_team_id": team_b["id"],
    },
)

concurrency_game_id = concurrency_game["id"]

initial_events = len(
    rest_get(
        f"/api/games/{concurrency_game_id}/scoring-events"
    )
)

initial_score = rest_get(
    f"/api/games/{concurrency_game_id}"
)["home_score"]

concurrency_payload = {
    "game_id": concurrency_game_id,
    "team_id": team["id"],
    "player_id": None,
    "event_type": "goal",
}


def post_goal():
    req = urllib.request.Request(
        f"{BASE_URL}/api/scoring-events",
        data=json.dumps(
            concurrency_payload
        ).encode(),
        headers={
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req) as resp:
            return (
                resp.status,
                json.loads(resp.read()),
            )

    except urllib.error.HTTPError as exc:
        return (
            exc.code,
            {},
        )


clear_events()

with concurrent.futures.ThreadPoolExecutor(
    max_workers=10
) as executor:

    futures = [
        executor.submit(post_goal)
        for _ in range(10)
    ]

    results_list = [
        future.result()
        for future in concurrent.futures.as_completed(
            futures
        )
    ]

success_count = sum(
    1
    for status, _ in results_list
    if status == 201
)

time.sleep(1.0)

final_score = rest_get(
    f"/api/games/{concurrency_game_id}"
)["home_score"]

final_events = len(
    rest_get(
        f"/api/games/{concurrency_game_id}/scoring-events"
    )
)

score_delta = (
    final_score
    - initial_score
)

event_delta = (
    final_events
    - initial_events
)

scoring_events_received = sum(
    1
    for event in m7_events
    if event[0] == "scoring_event:created"
)

score_updates_received = sum(
    1
    for event in m7_events
    if event[0] == "game:score_updated"
)

print(
    "  Requests: 10",
    flush=True,
)

print(
    f"  Successful: {success_count}",
    flush=True,
)

print(
    f"  Score delta: {score_delta}",
    flush=True,
)

print(
    f"  Event DB delta: {event_delta}",
    flush=True,
)

print(
    f"  scoring_event:created received: "
    f"{scoring_events_received}",
    flush=True,
)

print(
    f"  game:score_updated received: "
    f"{score_updates_received}",
    flush=True,
)

check(
    "Concurrency: score delta matches successful",
    score_delta == success_count,
)

check(
    "Concurrency: event DB delta matches successful",
    event_delta == success_count,
)

check(
    "Concurrency: scoring_event:created count matches",
    scoring_events_received == success_count,
)

check(
    "Concurrency: game:score_updated count matches",
    score_updates_received == success_count,
)

# ============================================================
# Disconnect / Reconnect
# ============================================================
sio.disconnect()
time.sleep(0.5)

# Important: remove the ORIGINAL connection:ready so this test
# requires a fresh connection:ready event after reconnect.
clear_events()

sio.connect(
    BASE_URL,
    socketio_path="/socket.io",
    transports=["polling"],
)

time.sleep(0.5)

check(
    "Reconnect successful",
    sio.connected
    and wait_for_event("connection:ready"),
)

sio.disconnect()

# ============================================================
# Socket.IO Summary
# ============================================================
print("")
print("========================================")
print("Socket.IO M7-C Tests Complete")
print(
    f"Passed: {results['pass']} "
    f"Failed: {results['fail']}"
)
print("========================================")

if results["fail"] > 0:
    sys.exit(1)
PYTHON_EOF

# ============================================================
# Run Python Socket.IO Tests
#
# tee displays output LIVE while also saving it so this Bash
# script can count PASS/FAIL results afterward.
# ============================================================
set +e

sudo docker compose exec -T app \
    python3 - "$BASE_URL" \
    < "$PY_TEST_FILE" 2>&1 \
    | tee "$SIO_OUTPUT"

SIO_EXIT=${PIPESTATUS[0]}

set -e

rm -f "$PY_TEST_FILE"

SIO_RESULT=$(cat "$SIO_OUTPUT")

rm -f "$SIO_OUTPUT"

if [ "$SIO_EXIT" -ne 0 ]; then
    fail "Socket.IO M7-C test process exited with code $SIO_EXIT"
fi

SIO_PASS=$(
    echo "$SIO_RESULT" \
    | grep -oP "Passed: \K[0-9]+" \
    || echo "0"
)

SIO_FAIL=$(
    echo "$SIO_RESULT" \
    | grep -oP "Failed: \K[0-9]+" \
    || echo "0"
)

PASS=$((PASS + SIO_PASS))
FAIL=$((FAIL + SIO_FAIL))

# ============================================================
# 5. Prior Regression Harnesses
# ============================================================
echo ""
echo "Running prior regression harnesses..."

if ./scripts/validate_m7a.sh >/dev/null 2>&1; then
    pass "M7-A regression passed"
else
    fail "M7-A regression failed"
fi

# IMPORTANT:
#
# We do not call validate_m7b.sh here.
#
# M7-B REST/persistence behavior is already tested directly above.
# The original M7-B checkpoint script may contain the intentional
# pre-M7-C assertion that scoring Socket.IO events do not exist.
# Once M7-C exists, that old assertion is no longer valid.

if ./scripts/validate_m6.sh >/dev/null 2>&1; then
    pass "M6 regression passed"
else
    fail "M6 regression failed"
fi

# ============================================================
# Final Summary
# ============================================================
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "M7-C VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M7-C VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi