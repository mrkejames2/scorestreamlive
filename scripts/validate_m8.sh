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

is_local_target() {
    case "$BASE_URL" in
        http://localhost:*|https://localhost:*|\
        http://127.0.0.1:*|https://127.0.0.1:*|\
        http://192.168.*|https://192.168.*|\
        http://10.*|https://10.*|\
        http://172.16.*|http://172.17.*|http://172.18.*|http://172.19.*|\
        http://172.2?.*|http://172.3[01].*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

run_child_harness() {
    local label="$1"
    local script="$2"
    local output_file
    local rc
    local child_pass
    local child_fail

    output_file=$(mktemp)

    echo ""
    echo "========================================"
    echo "Running ${label}"
    echo "========================================"

    set +e
    BASE_URL="$BASE_URL" "$script" 2>&1 | tee "$output_file"
    rc=${PIPESTATUS[0]}
    set -e

    child_pass=$(grep -oP 'Passed: \K[0-9]+' "$output_file" | tail -1 || true)
    child_fail=$(grep -oP 'Failed: \K[0-9]+' "$output_file" | tail -1 || true)

    child_pass="${child_pass:-0}"
    child_fail="${child_fail:-0}"

    rm -f "$output_file"

    PASS=$((PASS + child_pass))
    FAIL=$((FAIL + child_fail))

    if [ "$rc" -eq 0 ]; then
        pass "${label} process passed"
        return 0
    fi

    fail "${label} process failed with exit code ${rc}"
    return "$rc"
}

run_local_restart_test() {
    echo ""
    echo "========================================"
    echo "M8-D Application Restart Clock Test"
    echo "========================================"

    local py_file
    local state_file
    py_file=$(mktemp)
    state_file=$(mktemp)

    cat > "$py_file" <<'PY'
import json
import os
import sys
import urllib.request

base = os.environ["BASE_URL"]

def req(method, path, payload=None):
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(
        base + path,
        data=data,
        headers=headers,
        method=method,
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.status, json.loads(response.read())

def create_team(name, short):
    return req("POST", "/api/teams", {"name": name, "short_name": short})[1]

suffix = os.getpid()
a = create_team(f"M8D-R-A-{suffix}", "RA")
b = create_team(f"M8D-R-B-{suffix}", "RB")

game = req(
    "POST",
    "/api/games",
    {
        "name": f"M8D-RESTART-{suffix}",
        "home_team_id": a["id"],
        "away_team_id": b["id"],
    },
)[1]

clock = req(
    "POST",
    f"/api/games/{game['id']}/clock",
    {"mode": "count_up", "duration_seconds": 2700},
)[1]

started = req(
    "POST",
    f"/api/games/{game['id']}/clock/start",
    {"expected_version": clock["version"]},
)[1]

print(json.dumps({
    "game_id": game["id"],
    "version": started["version"],
    "elapsed_before": started["authoritative_elapsed_seconds"],
}))
PY

    BASE_URL="$BASE_URL" python3 "$py_file" > "$state_file"

    local game_id
    local before
    local version

    game_id=$(python3 -c "import json; print(json.load(open('$state_file'))['game_id'])")
    before=$(python3 -c "import json; print(json.load(open('$state_file'))['elapsed_before'])")
    version=$(python3 -c "import json; print(json.load(open('$state_file'))['version'])")

    rm -f "$py_file" "$state_file"

    sleep 2

    if docker compose restart app >/dev/null 2>&1; then
        pass "Application container restarted while clock running"
    else
        fail "Application container restart failed"
        return 1
    fi

    local ready=0
    for _ in $(seq 1 30); do
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health/ready" || true)
        if [ "$code" = "200" ]; then
            ready=1
            break
        fi
        sleep 1
    done

    if [ "$ready" -eq 1 ]; then
        pass "Application became ready after restart"
    else
        fail "Application did not become ready after restart"
        return 1
    fi

    local state
    state=$(curl -s "${BASE_URL}/api/games/${game_id}/clock")

    local after
    local after_version
    local status

    after=$(echo "$state" | python3 -c "import sys,json; print(json.load(sys.stdin)['authoritative_elapsed_seconds'])")
    after_version=$(echo "$state" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
    status=$(echo "$state" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")

    if [ "$status" = "running" ]; then
        pass "Clock remains running after application restart"
    else
        fail "Clock status after restart is ${status}"
    fi

    if [ "$after_version" = "$version" ]; then
        pass "Clock version survives restart unchanged"
    else
        fail "Clock version changed across restart (${version} -> ${after_version})"
    fi

    if [ "$after" -gt "$before" ]; then
        pass "Clock elapsed time includes application restart interval"
    else
        fail "Clock did not advance across restart (${before} -> ${after})"
    fi

    local pause_code
    pause_code=$(curl -s -o /tmp/m8d_pause.json -w "%{http_code}" \
        -X POST \
        "${BASE_URL}/api/games/${game_id}/clock/pause" \
        -H "Content-Type: application/json" \
        -d "{\"expected_version\":${after_version}}")

    if [ "$pause_code" = "200" ]; then
        pass "Clock can be paused successfully after restart"
    else
        fail "Clock pause after restart returned ${pause_code}"
    fi

    rm -f /tmp/m8d_pause.json
}

run_remote_clock_test() {
    echo ""
    echo "========================================"
    echo "M8 Production / Remote Clock Test"
    echo "========================================"

    local py_file
    local output_file
    local rc
    local remote_pass
    local remote_fail

    py_file=$(mktemp)
    output_file=$(mktemp)

    cat > "$py_file" <<'PY'
import concurrent.futures
import json
import os
import sys
import threading
import time
import urllib.error
import urllib.request

import socketio

base = os.environ["BASE_URL"]
prefix = f"M8-REMOTE-{int(time.time())}"
counts = {"pass": 0, "fail": 0}

def check(label, condition):
    if condition:
        print(f"[PASS] {label}", flush=True)
        counts["pass"] += 1
    else:
        print(f"[FAIL] {label}", flush=True)
        counts["fail"] += 1

def req(method, path, payload=None, allow_error=False):
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(
        base + path,
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        body = json.loads(raw) if raw else None
        if allow_error:
            return exc.code, body
        raise

class Client:
    def __init__(self):
        self.sio = socketio.Client()
        self.events = []
        self.ticks = []
        self.lock = threading.Lock()

        @self.sio.on("clock:updated")
        def clock_updated(data):
            with self.lock:
                self.events.append(data)

        @self.sio.on("clock:tick")
        def clock_tick(data):
            with self.lock:
                self.ticks.append(data)

    def connect(self):
        self.sio.connect(
            base,
            socketio_path="/socket.io",
            transports=["polling"],
            wait_timeout=15,
        )

    def disconnect(self):
        if self.sio.connected:
            self.sio.disconnect()

    def wait(self, game_id, version, timeout=7):
        deadline = time.time() + timeout
        while time.time() < deadline:
            with self.lock:
                matches = [
                    x for x in self.events
                    if x.get("game_id") == game_id
                    and x.get("version") == version
                ]
            if matches:
                return matches[-1]
            time.sleep(.05)
        return None

for path in ("/health/live", "/health/ready", "/info"):
    status, _ = req("GET", path)
    check(path, status == 200)

a = req("POST", "/api/teams", {"name": prefix + "-A", "short_name": "A"})[1]
b = req("POST", "/api/teams", {"name": prefix + "-B", "short_name": "B"})[1]
game = req(
    "POST",
    "/api/games",
    {
        "name": prefix + "-GAME",
        "home_team_id": a["id"],
        "away_team_id": b["id"],
    },
)[1]

c1 = Client()
c2 = Client()

try:
    c1.connect()
    c2.connect()

    check("Remote Client A connected", c1.sio.connected)
    check("Remote Client B connected", c2.sio.connected)

    status, clock = req(
        "POST",
        f"/api/games/{game['id']}/clock",
        {"mode": "count_up", "duration_seconds": 2700},
    )
    check("Remote clock creation 201", status == 201)
    check("Both clients receive version 1",
          c1.wait(game["id"], 1) is not None and
          c2.wait(game["id"], 1) is not None)

    status, started = req(
        "POST",
        f"/api/games/{game['id']}/clock/start",
        {"expected_version": 1},
    )
    check("Remote start 200", status == 200)
    check("Both clients receive version 2",
          c1.wait(game["id"], 2) is not None and
          c2.wait(game["id"], 2) is not None)

    time.sleep(2)

    _, current = req("GET", f"/api/games/{game['id']}/clock")
    check(
        "Remote clock advances without ticks",
        current["authoritative_elapsed_seconds"] >= 1
        and len(c1.ticks) == 0
        and len(c2.ticks) == 0,
    )

    def pause_same_version():
        return req(
            "POST",
            f"/api/games/{game['id']}/clock/pause",
            {"expected_version": 2},
            allow_error=True,
        )[0]

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        statuses = sorted([
            pool.submit(pause_same_version).result(),
            pool.submit(pause_same_version).result(),
        ])

    check(
        "Remote same-version controllers: one 200 / one 409",
        statuses == [200, 409],
    )

    _, paused = req("GET", f"/api/games/{game['id']}/clock")
    check("Remote final version is 3", paused["version"] == 3)
    check("Remote final status paused", paused["status"] == "paused")

    status, configured = req(
        "PATCH",
        f"/api/games/{game['id']}/clock",
        {
            "expected_version": 3,
            "mode": "count_down",
            "duration_seconds": 5,
        },
    )
    check("Remote configuration 200", status == 200)
    check("Remote configuration version 4", configured["version"] == 4)

    status, reset = req(
        "POST",
        f"/api/games/{game['id']}/clock/reset",
        {"expected_version": 4},
    )
    check("Remote reset 200", status == 200)
    check(
        "Remote count-down reset displays duration",
        reset["display_seconds"] == 5,
    )

finally:
    c1.disconnect()
    c2.disconnect()

print("========================================")
print(f"Remote M8 Clock Tests Passed: {counts['pass']} Failed: {counts['fail']}")
print("========================================")

if counts["fail"]:
    sys.exit(1)
PY

    set +e
    docker compose exec -T \
        -e BASE_URL="$BASE_URL" \
        app python3 - \
        < "$py_file" 2>&1 \
        | tee "$output_file"
    rc=${PIPESTATUS[0]}
    set -e

    rm -f "$py_file"

    remote_pass=$(grep -oP 'Remote M8 Clock Tests Passed: \K[0-9]+' "$output_file" | tail -1 || true)
    remote_fail=$(grep -oP 'Failed: \K[0-9]+' "$output_file" | tail -1 || true)

    remote_pass="${remote_pass:-0}"
    remote_fail="${remote_fail:-0}"

    PASS=$((PASS + remote_pass))
    FAIL=$((FAIL + remote_fail))

    rm -f "$output_file"

    if [ "$rc" -eq 0 ]; then
        pass "Remote M8 clock process passed"
    else
        fail "Remote M8 clock process failed with exit code ${rc}"
    fi
}

echo "========================================"
echo "ScoreStreamLive Final Milestone 8 Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

if is_local_target; then
    echo "[INFO] Local/private target detected."

    CURRENT=$(docker compose exec -T app alembic current 2>/dev/null || true)
    if echo "$CURRENT" | grep -F "20260814_0005" >/dev/null; then
        pass "Alembic current is 20260814_0005"
    else
        echo "$CURRENT"
        fail "Alembic current is not 20260814_0005"
    fi

    run_child_harness \
        "M8-C final behavior / regression harness" \
        "./scripts/validate_m8c.sh" || true

    run_local_restart_test || true
else
    echo "[INFO] Remote production target detected."
    echo "[INFO] Remote migration revision must be confirmed from Render deployment logs."

    run_remote_clock_test || true

    # M7 final harness was explicitly hardened for production usage.
    run_child_harness \
        "M7 production regression harness" \
        "./scripts/validate_m7.sh" || true
fi

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "M8 VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M8 VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi
