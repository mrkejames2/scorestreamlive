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

echo "========================================"
echo "ScoreStreamLive M8-C Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

# ============================================================
# 1. Basic health
# ============================================================
for path in /health/live /health/ready /info; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}")

    if [ "$CODE" = "200" ]; then
        pass "$path"
    else
        fail "$path (got $CODE)"
    fi
done

# ============================================================
# 2. M8-C Socket.IO synchronization tests
# ============================================================
echo ""
echo "========================================"
echo "Socket.IO M8-C Clock Synchronization Tests"
echo "========================================"

PY_TEST_FILE=$(mktemp)
SIO_OUTPUT=$(mktemp)

cat > "$PY_TEST_FILE" <<'PYTHON_EOF'
import concurrent.futures
import json
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid

import socketio


BASE_URL = sys.argv[1]
PREFIX = f"M8C-{int(time.time())}"

results = {"pass": 0, "fail": 0}


def check(label, condition):
    if condition:
        print(f"[PASS] {label}", flush=True)
        results["pass"] += 1
    else:
        print(f"[FAIL] {label}", flush=True)
        results["fail"] += 1


def request_json(method, path, payload=None, expected_error=False):
    data = None
    headers = {}

    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            body = response.read()
            parsed = json.loads(body) if body else None
            return response.status, parsed
    except urllib.error.HTTPError as exc:
        body = exc.read()
        parsed = json.loads(body) if body else None
        if expected_error:
            return exc.code, parsed
        raise


def create_team(name, short_name):
    status, body = request_json(
        "POST",
        "/api/teams",
        {"name": name, "short_name": short_name},
    )
    assert status == 201
    return body


def create_game(name, home_id, away_id):
    status, body = request_json(
        "POST",
        "/api/games",
        {
            "name": name,
            "home_team_id": home_id,
            "away_team_id": away_id,
        },
    )
    assert status == 201
    return body


class TestClient:
    def __init__(self, name):
        self.name = name
        self.events = []
        self.tick_events = []
        self.ready_events = []
        self.lock = threading.Lock()
        self.sio = socketio.Client(
            reconnection=True,
            reconnection_attempts=5,
            reconnection_delay=1,
        )

        @self.sio.on("connection:ready")
        def on_ready(data):
            with self.lock:
                self.ready_events.append(data)

        @self.sio.on("clock:updated")
        def on_clock_updated(data):
            with self.lock:
                self.events.append(data)

        @self.sio.on("clock:tick")
        def on_clock_tick(data):
            with self.lock:
                self.tick_events.append(data)

    def connect(self):
        self.sio.connect(
            BASE_URL,
            socketio_path="/socket.io",
            transports=["polling"],
            wait_timeout=10,
        )

    def disconnect(self):
        if self.sio.connected:
            self.sio.disconnect()

    def clear_clock_events(self):
        with self.lock:
            self.events.clear()
            self.tick_events.clear()

    def matching(self, game_id, version=None):
        with self.lock:
            matches = [
                event
                for event in self.events
                if str(event.get("game_id")) == str(game_id)
            ]

        if version is not None:
            matches = [
                event
                for event in matches
                if event.get("version") == version
            ]

        return matches

    def wait_for_clock(self, game_id, version=None, timeout=5):
        deadline = time.time() + timeout

        while time.time() < deadline:
            matches = self.matching(game_id, version)
            if matches:
                return matches[-1]
            time.sleep(0.05)

        return None

    def wait_for_ready(self, timeout=5):
        deadline = time.time() + timeout

        while time.time() < deadline:
            with self.lock:
                if self.ready_events:
                    return True
            time.sleep(0.05)

        return False


client_a = TestClient("A")
client_b = TestClient("B")

try:
    client_a.connect()
    client_b.connect()

    check("Client A Socket.IO connected", client_a.sio.connected)
    check("Client B Socket.IO connected", client_b.sio.connected)
    check("Client A connection:ready received", client_a.wait_for_ready())
    check("Client B connection:ready received", client_b.wait_for_ready())

    team_a = create_team(f"{PREFIX}-TEAM-A", "TA")
    team_b = create_team(f"{PREFIX}-TEAM-B", "TB")
    game_a = create_game(
        f"{PREFIX}-GAME-A",
        team_a["id"],
        team_b["id"],
    )

    game_id = game_a["id"]

    # --------------------------------------------------------
    # Creation → clock:updated version 1 to both clients
    # --------------------------------------------------------
    client_a.clear_clock_events()
    client_b.clear_clock_events()

    status, created = request_json(
        "POST",
        f"/api/games/{game_id}/clock",
        {
            "mode": "count_up",
            "duration_seconds": 2700,
        },
    )

    check("Clock creation returns 201", status == 201)

    event_a = client_a.wait_for_clock(game_id, 1)
    event_b = client_b.wait_for_clock(game_id, 1)

    check("Client A receives clock:updated on creation", event_a is not None)
    check("Client B receives clock:updated on creation", event_b is not None)

    required_fields = {
        "id",
        "game_id",
        "mode",
        "status",
        "duration_seconds",
        "elapsed_seconds",
        "running_since",
        "version",
        "created_at",
        "updated_at",
        "server_time",
        "authoritative_elapsed_seconds",
        "display_seconds",
    }

    check(
        "clock:updated payload complete",
        event_a is not None
        and required_fields.issubset(set(event_a.keys())),
    )

    if event_a is not None:
        check("Creation event game_id matches", event_a["game_id"] == game_id)
        check("Creation event version is 1", event_a["version"] == 1)
        check("Creation event status stopped", event_a["status"] == "stopped")
        check("Creation event mode count_up", event_a["mode"] == "count_up")
        check("Creation event server_time present", bool(event_a["server_time"]))

    if event_a is not None and event_b is not None:
        check(
            "Both clients receive same creation version/state",
            (
                event_a["game_id"],
                event_a["version"],
                event_a["status"],
                event_a["elapsed_seconds"],
            )
            == (
                event_b["game_id"],
                event_b["version"],
                event_b["status"],
                event_b["elapsed_seconds"],
            ),
        )

    # --------------------------------------------------------
    # Start → committed version 2
    # --------------------------------------------------------
    client_a.clear_clock_events()
    client_b.clear_clock_events()

    status, start_body = request_json(
        "POST",
        f"/api/games/{game_id}/clock/start",
        {"expected_version": 1},
    )

    check("Start returns 200", status == 200)

    event_a = client_a.wait_for_clock(game_id, 2)
    event_b = client_b.wait_for_clock(game_id, 2)

    check("Client A receives start clock:updated", event_a is not None)
    check("Client B receives start clock:updated", event_b is not None)

    if event_a is not None:
        check("Start event status running", event_a["status"] == "running")
        check("Start event version 2", event_a["version"] == 2)
        check("Start event running_since present", bool(event_a["running_since"]))

    # REST committed state must match event's durable fields.
    _, rest_state = request_json(
        "GET",
        f"/api/games/{game_id}/clock",
    )

    if event_a is not None:
        check(
            "Start event matches committed REST state",
            all(
                event_a[key] == rest_state[key]
                for key in (
                    "id",
                    "game_id",
                    "mode",
                    "status",
                    "duration_seconds",
                    "elapsed_seconds",
                    "version",
                )
            ),
        )

        check(
            "Start event and REST both have running_since",
            bool(event_a["running_since"])
            and bool(rest_state["running_since"]),
        )

    # No per-second server ticks while clock is running.
    time.sleep(2.2)

    check(
        "No clock:tick received by Client A",
        len(client_a.tick_events) == 0,
    )
    check(
        "No clock:tick received by Client B",
        len(client_b.tick_events) == 0,
    )

    _, advanced_state = request_json(
        "GET",
        f"/api/games/{game_id}/clock",
    )

    check(
        "REST authoritative elapsed advances without tick events",
        advanced_state["authoritative_elapsed_seconds"] >= 1,
    )

    # --------------------------------------------------------
    # Pause → version 3
    # --------------------------------------------------------
    client_a.clear_clock_events()
    client_b.clear_clock_events()

    status, paused = request_json(
        "POST",
        f"/api/games/{game_id}/clock/pause",
        {"expected_version": 2},
    )

    check("Pause returns 200", status == 200)

    event_a = client_a.wait_for_clock(game_id, 3)
    event_b = client_b.wait_for_clock(game_id, 3)

    check("Client A receives pause clock:updated", event_a is not None)
    check("Client B receives pause clock:updated", event_b is not None)

    if event_a is not None:
        check("Pause event status paused", event_a["status"] == "paused")
        check("Pause event running_since null", event_a["running_since"] is None)
        check(
            "Pause event elapsed matches REST response",
            event_a["elapsed_seconds"] == paused["elapsed_seconds"],
        )

    # --------------------------------------------------------
    # Resume → version 4
    # --------------------------------------------------------
    client_a.clear_clock_events()
    client_b.clear_clock_events()

    status, resumed = request_json(
        "POST",
        f"/api/games/{game_id}/clock/resume",
        {"expected_version": 3},
    )

    check("Resume returns 200", status == 200)

    check(
        "Client A receives resume clock:updated",
        client_a.wait_for_clock(game_id, 4) is not None,
    )
    check(
        "Client B receives resume clock:updated",
        client_b.wait_for_clock(game_id, 4) is not None,
    )

    # --------------------------------------------------------
    # Failed stale command → no event
    # --------------------------------------------------------
    client_a.clear_clock_events()
    client_b.clear_clock_events()

    status, _ = request_json(
        "POST",
        f"/api/games/{game_id}/clock/pause",
        {"expected_version": 3},
        expected_error=True,
    )

    check("Stale command rejected 409", status == 409)

    time.sleep(0.6)

    check(
        "Stale command emits no clock:updated to Client A",
        len(client_a.matching(game_id)) == 0,
    )
    check(
        "Stale command emits no clock:updated to Client B",
        len(client_b.matching(game_id)) == 0,
    )

    # --------------------------------------------------------
    # Valid pause → 5; configure → 6; reset → 7
    # --------------------------------------------------------
    status, _ = request_json(
        "POST",
        f"/api/games/{game_id}/clock/pause",
        {"expected_version": 4},
    )
    check("Second pause returns 200", status == 200)
    check(
        "Both clients receive version 5 pause",
        client_a.wait_for_clock(game_id, 5) is not None
        and client_b.wait_for_clock(game_id, 5) is not None,
    )

    client_a.clear_clock_events()
    client_b.clear_clock_events()

    status, configured = request_json(
        "PATCH",
        f"/api/games/{game_id}/clock",
        {
            "expected_version": 5,
            "mode": "count_down",
            "duration_seconds": 10,
        },
    )

    check("Configuration returns 200", status == 200)

    config_a = client_a.wait_for_clock(game_id, 6)
    config_b = client_b.wait_for_clock(game_id, 6)

    check("Client A receives configuration clock:updated", config_a is not None)
    check("Client B receives configuration clock:updated", config_b is not None)

    if config_a is not None:
        check("Configuration event mode count_down", config_a["mode"] == "count_down")
        check("Configuration event duration 10", config_a["duration_seconds"] == 10)

    client_a.clear_clock_events()
    client_b.clear_clock_events()

    status, reset = request_json(
        "POST",
        f"/api/games/{game_id}/clock/reset",
        {"expected_version": 6},
    )

    check("Reset returns 200", status == 200)

    reset_a = client_a.wait_for_clock(game_id, 7)
    reset_b = client_b.wait_for_clock(game_id, 7)

    check("Client A receives reset clock:updated", reset_a is not None)
    check("Client B receives reset clock:updated", reset_b is not None)

    if reset_a is not None:
        check("Reset event stopped", reset_a["status"] == "stopped")
        check("Reset event elapsed 0", reset_a["elapsed_seconds"] == 0)

    # --------------------------------------------------------
    # Failed reset while running → no event
    # --------------------------------------------------------
    status, _ = request_json(
        "POST",
        f"/api/games/{game_id}/clock/start",
        {"expected_version": 7},
    )
    check("Count-down start for failure test returns 200", status == 200)

    check(
        "Both clients receive version 8 start",
        client_a.wait_for_clock(game_id, 8) is not None
        and client_b.wait_for_clock(game_id, 8) is not None,
    )

    client_a.clear_clock_events()
    client_b.clear_clock_events()

    status, _ = request_json(
        "POST",
        f"/api/games/{game_id}/clock/reset",
        {"expected_version": 8},
        expected_error=True,
    )

    check("Reset while running rejected 409", status == 409)

    time.sleep(0.6)

    check(
        "Failed reset emits no clock:updated to Client A",
        len(client_a.matching(game_id)) == 0,
    )
    check(
        "Failed reset emits no clock:updated to Client B",
        len(client_b.matching(game_id)) == 0,
    )

    # --------------------------------------------------------
    # Same-version concurrent controllers → one committed event
    # --------------------------------------------------------
    game_c = create_game(
        f"{PREFIX}-GAME-CONCURRENT",
        team_a["id"],
        team_b["id"],
    )
    concurrent_game_id = game_c["id"]

    status, _ = request_json(
        "POST",
        f"/api/games/{concurrent_game_id}/clock",
        {
            "mode": "count_up",
            "duration_seconds": 2700,
        },
    )
    check("Concurrent clock creation returns 201", status == 201)

    check(
        "Both clients receive concurrent clock creation",
        client_a.wait_for_clock(concurrent_game_id, 1) is not None
        and client_b.wait_for_clock(concurrent_game_id, 1) is not None,
    )

    client_a.clear_clock_events()
    client_b.clear_clock_events()

    def concurrent_start():
        return request_json(
            "POST",
            f"/api/games/{concurrent_game_id}/clock/start",
            {"expected_version": 1},
            expected_error=True,
        )[0]

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        statuses = sorted(
            [
                future.result()
                for future in [
                    pool.submit(concurrent_start),
                    pool.submit(concurrent_start),
                ]
            ]
        )

    check(
        "Concurrent same-version commands yield one 200 and one 409",
        statuses == [200, 409],
    )

    time.sleep(0.7)

    a_v2 = client_a.matching(concurrent_game_id, 2)
    b_v2 = client_b.matching(concurrent_game_id, 2)

    check(
        "Client A receives exactly one committed version-2 event",
        len(a_v2) == 1,
    )
    check(
        "Client B receives exactly one committed version-2 event",
        len(b_v2) == 1,
    )

    # --------------------------------------------------------
    # Multi-Game isolation via game_id
    # --------------------------------------------------------
    game_b = create_game(
        f"{PREFIX}-GAME-B",
        team_a["id"],
        team_b["id"],
    )
    game_b_id = game_b["id"]

    client_a.clear_clock_events()
    client_b.clear_clock_events()

    status, _ = request_json(
        "POST",
        f"/api/games/{game_b_id}/clock",
        {
            "mode": "count_down",
            "duration_seconds": 1200,
        },
    )

    check("Game B clock creation returns 201", status == 201)

    b_event_a = client_a.wait_for_clock(game_b_id, 1)
    b_event_b = client_b.wait_for_clock(game_b_id, 1)

    check("Client A receives Game B event with Game B id", b_event_a is not None)
    check("Client B receives Game B event with Game B id", b_event_b is not None)

    _, concurrent_state_before = request_json(
        "GET",
        f"/api/games/{concurrent_game_id}/clock",
    )

    status, _ = request_json(
        "POST",
        f"/api/games/{game_b_id}/clock/start",
        {"expected_version": 1},
    )
    check("Game B start returns 200", status == 200)

    _, concurrent_state_after = request_json(
        "GET",
        f"/api/games/{concurrent_game_id}/clock",
    )

    check(
        "Game B mutation does not alter other Game version/status",
        (
            concurrent_state_before["version"],
            concurrent_state_before["status"],
            concurrent_state_before["running_since"],
        )
        == (
            concurrent_state_after["version"],
            concurrent_state_after["status"],
            concurrent_state_after["running_since"],
        ),
    )

    # --------------------------------------------------------
    # Disconnect/reconnect: recover authoritative running state via REST
    # --------------------------------------------------------
    _, before_disconnect = request_json(
        "GET",
        f"/api/games/{game_b_id}/clock",
    )

    before_elapsed = before_disconnect["authoritative_elapsed_seconds"]

    client_b.disconnect()
    check("Client B disconnected", not client_b.sio.connected)

    time.sleep(2.0)

    client_b.ready_events.clear()
    client_b.connect()

    check("Client B reconnects", client_b.sio.connected)
    check(
        "Client B receives new connection:ready after reconnect",
        client_b.wait_for_ready(),
    )

    _, recovered = request_json(
        "GET",
        f"/api/games/{game_b_id}/clock",
    )

    check(
        "REST recovery after reconnect reflects elapsed disconnect interval",
        recovered["authoritative_elapsed_seconds"] > before_elapsed,
    )

    check(
        "Recovered Game B version remains authoritative",
        recovered["version"] == 2,
    )

    # --------------------------------------------------------
    # Final no-tick assertion
    # --------------------------------------------------------
    time.sleep(1.2)

    check(
        "No per-second clock:tick architecture observed",
        len(client_a.tick_events) == 0
        and len(client_b.tick_events) == 0,
    )

finally:
    client_a.disconnect()
    client_b.disconnect()

print("")
print("========================================")
print("Socket.IO M8-C Tests Complete")
print(f"Passed: {results['pass']} Failed: {results['fail']}")
print("========================================")

if results["fail"]:
    sys.exit(1)
PYTHON_EOF

set +e

docker compose exec -T app \
    python3 - "$BASE_URL" \
    < "$PY_TEST_FILE" 2>&1 \
    | tee "$SIO_OUTPUT"

SIO_RC=${PIPESTATUS[0]}

set -e

rm -f "$PY_TEST_FILE"

SIO_PASS=$(
    grep -oP 'Passed: \K[0-9]+' "$SIO_OUTPUT" \
    | tail -1 \
    || true
)

SIO_FAIL=$(
    grep -oP 'Failed: \K[0-9]+' "$SIO_OUTPUT" \
    | tail -1 \
    || true
)

SIO_PASS="${SIO_PASS:-0}"
SIO_FAIL="${SIO_FAIL:-0}"

PASS=$((PASS + SIO_PASS))
FAIL=$((FAIL + SIO_FAIL))

rm -f "$SIO_OUTPUT"

if [ "$SIO_RC" -eq 0 ]; then
    pass "M8-C Socket.IO test process passed"
else
    fail "M8-C Socket.IO test process failed with exit code ${SIO_RC}"
fi

# ============================================================
# 3. M8-B REST/service regression
# ============================================================
echo ""
echo "========================================"
echo "Running M8-B REST / Service Regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m8b.sh
M8B_RC=$?
set -e

if [ "$M8B_RC" -eq 0 ]; then
    pass "M8-B REST/service regression passed"
else
    fail "M8-B REST/service regression failed"
fi

# ============================================================
# 4. Final summary
# ============================================================
echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "M8-C VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M8-C VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi
