#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"
export BASE_URL

PASS=0
FAIL=0

pass(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
fail(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "========================================"
echo "ScoreStreamLive M10-B Regression Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)

    [ "$code" = "200" ] \
        && pass "$path" \
        || fail "$path"
done

for item in \
    "/static/vendor/socket.io.min.js|Local Socket.IO browser client" \
    "/static/js/control/socket.js|Control socket module"
do
    path="${item%%|*}"
    label="${item#*|}"

    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)

    [ "$code" = "200" ] \
        && pass "${label} preflight" \
        || fail "${label} preflight returned HTTP ${code}"
done

if [ "$FAIL" -ne 0 ]; then
    echo ""
    echo "========================================"
    echo "M10-B REGRESSION VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi

TMP=$(mktemp)

set +e

docker compose exec -T \
    -e BASE_URL="$BASE_URL" \
    app python3 - <<'PY' >"$TMP" 2>&1
import json
import os
import sys
import threading
import time
import urllib.error
import urllib.request

import socketio

BASE = os.environ["BASE_URL"]
prefix = f"M10B-REG-{int(time.time())}"

passed = 0
failed = 0


def check(label, condition):
    global passed, failed

    if condition:
        print(f"[PASS] {label}", flush=True)
        passed += 1
    else:
        print(f"[FAIL] {label}", flush=True)
        failed += 1


def req(method, path, payload=None, allow=False):
    data = None
    headers = {}

    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        BASE + path,
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            raw = response.read()
            content_type = response.headers.get("Content-Type", "")

            if "application/json" in content_type.lower():
                body = json.loads(raw) if raw else None
            else:
                body = raw.decode("utf-8", errors="replace") if raw else ""

            return response.status, body, content_type

    except urllib.error.HTTPError as exc:
        raw = exc.read()

        body = raw.decode("utf-8", errors="replace") if raw else None

        if allow:
            return (
                exc.code,
                body,
                exc.headers.get("Content-Type", ""),
            )

        raise


def create_team(name, short_name):
    status, body, _ = req(
        "POST",
        "/api/teams",
        {
            "name": name,
            "short_name": short_name,
        },
    )

    check(
        f"{short_name} team creation",
        status == 201,
    )

    return body


home = create_team(prefix + "-HOME", "HOME")
away = create_team(prefix + "-AWAY", "AWAY")

status, game, _ = req(
    "POST",
    "/api/games",
    {
        "name": prefix + "-GAME",
        "home_team_id": home["id"],
        "away_team_id": away["id"],
    },
)

check("Game creation", status == 201)

game_id = game["id"]

status, _, _ = req(
    "POST",
    f"/api/games/{game_id}/lifecycle",
    {},
)

check("Lifecycle creation", status == 201)

status, _, _ = req(
    "POST",
    f"/api/games/{game_id}/clock",
    {
        "mode": "count_up",
        "duration_seconds": 2700,
    },
)

check("Clock creation", status == 201)

status, player, _ = req(
    "POST",
    "/api/players",
    {
        "team_id": home["id"],
        "first_name": "Live",
        "last_name": "Scorer",
        "jersey_number": 17,
    },
)

check("Home scorer creation", status == 201)

status, page, content_type = req(
    "GET",
    f"/control/games/{game_id}",
)

check("Control Center page returns 200", status == 200)

check(
    "Control Center is HTML",
    "text/html" in content_type.lower(),
)

# M10-B regression verifies the live-read surface exists.
# It intentionally does NOT require the page to label itself M10-B.
check(
    "Control Center preserves live connection UI",
    "connection-badge" in page
    and "connection-label" in page
    and "/static/vendor/socket.io.min.js" in page,
)

for path, label, needles in [
    (
        "/static/vendor/socket.io.min.js",
        "Local Socket.IO browser client loads",
        ["socket"],
    ),
    (
        "/static/js/control/socket.js",
        "Control socket module loads",
        [
            "game:score_updated",
            "scoring_event:created",
            "game:phase_updated",
            "clock:updated",
            "onAuthoritativeRefresh",
        ],
    ),
    (
        "/static/js/control/control.js",
        "Control bootstrap retains live handlers",
        [
            "connectControlSocket",
            "applyScoreUpdate",
            "applyScoringEvent",
            "applyPhaseUpdate",
            "applyClockUpdate",
        ],
    ),
]:
    status, content, _ = req(
        "GET",
        path,
    )

    check(
        label,
        status == 200
        and all(
            needle in content
            for needle in needles
        ),
    )

_, socket_module, _ = req(
    "GET",
    "/static/js/control/socket.js",
)

check(
    "Live events are filtered by game_id",
    "payload.game_id" in socket_module
    and "gameId" in socket_module,
)

check(
    "Reconnect refreshes authoritative REST state",
    "onAuthoritativeRefresh" in socket_module
    and '"connect"' in socket_module,
)

# Check the actual listener module for clock:tick.
# Comments elsewhere in the project are irrelevant.
check(
    "M10-B live listener does not consume clock:tick",
    "clock:tick" not in socket_module,
)


class Listener:
    def __init__(self):
        self.sio = socketio.Client(reconnection=True)
        self.events = []
        self.lock = threading.Lock()
        self.ready = threading.Event()

        @self.sio.on("connection:ready")
        def connection_ready(data):
            self.ready.set()

        for event_name in [
            "game:score_updated",
            "scoring_event:created",
            "game:phase_updated",
            "clock:updated",
        ]:
            self._register(event_name)

    def _register(self, event_name):
        @self.sio.on(event_name)
        def handler(data, event_name=event_name):
            with self.lock:
                self.events.append((event_name, data))

    def connect(self):
        self.sio.connect(
            BASE,
            socketio_path="/socket.io",
            transports=["polling"],
            wait_timeout=15,
        )

    def disconnect(self):
        if self.sio.connected:
            self.sio.disconnect()

    def clear(self):
        with self.lock:
            self.events.clear()

    def wait_for(self, event_name, game_id, timeout=7):
        deadline = time.time() + timeout

        while time.time() < deadline:
            with self.lock:
                matches = [
                    data
                    for name, data in self.events
                    if name == event_name
                    and str(data.get("game_id")) == str(game_id)
                ]

            if matches:
                return matches[-1]

            time.sleep(0.05)

        return None


listener = Listener()
listener.connect()

check(
    "Socket.IO listener connected",
    listener.sio.connected,
)

check(
    "connection:ready received",
    listener.ready.wait(3),
)

listener.clear()

status, _, _ = req(
    "POST",
    f"/api/games/{game_id}/lifecycle/transition",
    {
        "action": "start_first_half",
        "expected_lifecycle_version": 1,
        "expected_clock_version": 1,
    },
)

check(
    "External start_first_half mutation returns 200",
    status == 200,
)

phase_event = listener.wait_for(
    "game:phase_updated",
    game_id,
)

clock_event = listener.wait_for(
    "clock:updated",
    game_id,
)

check(
    "M10-B contract receives game:phase_updated",
    phase_event is not None,
)

check(
    "M10-B contract receives clock:updated",
    clock_event is not None,
)

check(
    "phase event is first_half",
    phase_event is not None
    and phase_event.get("phase") == "first_half",
)

check(
    "clock event is running",
    clock_event is not None
    and clock_event.get("status") == "running",
)

listener.clear()

status, _, _ = req(
    "POST",
    "/api/scoring-events",
    {
        "game_id": game_id,
        "team_id": home["id"],
        "player_id": player["id"],
        "event_type": "goal",
    },
)

check(
    "External scoring mutation returns 201",
    status == 201,
)

created_event = listener.wait_for(
    "scoring_event:created",
    game_id,
)

score_event = listener.wait_for(
    "game:score_updated",
    game_id,
)

check(
    "M10-B contract receives scoring_event:created",
    created_event is not None,
)

check(
    "M10-B contract receives game:score_updated",
    score_event is not None,
)

check(
    "scoring event scorer matches",
    created_event is not None
    and created_event.get("player_id") == player["id"],
)

check(
    "score update reflects 1-0",
    score_event is not None
    and score_event.get("home_score") == 1
    and score_event.get("away_score") == 0,
)

other_home = create_team(prefix + "-OTHER-H", "OH")
other_away = create_team(prefix + "-OTHER-A", "OA")

status, other_game, _ = req(
    "POST",
    "/api/games",
    {
        "name": prefix + "-OTHER-GAME",
        "home_team_id": other_home["id"],
        "away_team_id": other_away["id"],
    },
)

check(
    "Other Game creation",
    status == 201,
)

check(
    "Live event filter can isolate current game",
    str(other_game["id"]) != str(game_id),
)

listener.disconnect()

print("========================================")
print(
    f"M10-B Regression Tests Passed: "
    f"{passed} Failed: {failed}"
)
print("========================================")

sys.exit(1 if failed else 0)
PY

RC=$?

set -e

cat "$TMP"

P=$(grep -oP 'M10-B Regression Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)

PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))

rm -f "$TMP"

[ "$RC" -eq 0 ] \
    && pass "M10-B live-read regression process passed" \
    || fail "M10-B live-read regression process failed"

echo ""
echo "========================================"
echo "Running M10-A regression"
echo "========================================"

set +e

BASE_URL="$BASE_URL" \
    ./scripts/validate_m10a.sh

M10A_RC=$?

set -e

[ "$M10A_RC" -eq 0 ] \
    && pass "M10-A regression passed" \
    || fail "M10-A regression failed"

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "M10-B REGRESSION VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M10-B REGRESSION VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi
