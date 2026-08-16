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

a = create_team("M8-REGRESSION-RESTART-A", "RA")
b = create_team("M8-REGRESSION-RESTART-B", "RB")

game = req(
    "POST",
    "/api/games",
    {
        "name": "M8-REGRESSION-RESTART-GAME",
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

    [ "$status" = "running" ] \
        && pass "Clock remains running after application restart" \
        || fail "Clock status after restart is ${status}"

    [ "$after_version" = "$version" ] \
        && pass "Clock version survives restart unchanged" \
        || fail "Clock version changed across restart (${version} -> ${after_version})"

    [ "$after" -gt "$before" ] \
        && pass "Clock elapsed time includes application restart interval" \
        || fail "Clock did not advance across restart (${before} -> ${after})"

    local pause_code
    pause_code=$(curl -s -o /tmp/m8_regression_pause.json -w "%{http_code}" \
        -X POST \
        "${BASE_URL}/api/games/${game_id}/clock/pause" \
        -H "Content-Type: application/json" \
        -d "{\"expected_version\":${after_version}}")

    [ "$pause_code" = "200" ] \
        && pass "Clock can be paused successfully after restart" \
        || fail "Clock pause after restart returned ${pause_code}"

    rm -f /tmp/m8_regression_pause.json
}

echo "========================================"
echo "ScoreStreamLive Milestone 8 Regression Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

if is_local_target; then
    echo "[INFO] Local/private target detected."
    echo "[INFO] Historical M8 regression permits newer Alembic heads."

    HISTORY=$(docker compose exec -T app alembic history 2>/dev/null || true)

    if grep -F "20260815_0006" <<< "$HISTORY" >/dev/null; then
        pass "Alembic history contains M8 revision 20260815_0006"
    else
        echo "$HISTORY"
        fail "Alembic history does not contain M8 revision 20260815_0006"
    fi

    run_child_harness \
        "M8-C final behavior / regression harness" \
        "./scripts/validate_m8c.sh" || true

    run_local_restart_test || true
else
    echo "[INFO] Remote target detected."
    echo "[INFO] Use the active milestone production harness for new production validation."

    run_child_harness \
        "M8-C remote behavior / regression harness" \
        "./scripts/validate_m8c.sh" || true
fi

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "M8 REGRESSION VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M8 REGRESSION VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi
