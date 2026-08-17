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
echo "ScoreStreamLive M10-C Validation"
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
    "/static/js/control/socket.js|Control socket module" \
    "/static/js/control/control.js|M10-C control module"
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
    echo "M10-C VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi

TMP=$(mktemp)

set +e

docker compose exec -T \
    -e BASE_URL="$BASE_URL" \
    app python3 - <<'PY' >"$TMP" 2>&1
import concurrent.futures
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = os.environ["BASE_URL"]
prefix = f"M10C-{int(time.time())}"

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
        content_type = exc.headers.get("Content-Type", "")

        if raw:
            try:
                body = json.loads(raw)
            except Exception:
                body = raw.decode("utf-8", errors="replace")
        else:
            body = None

        if allow:
            return exc.code, body, content_type

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


def setup_game(name):
    home = create_team(name + "-HOME", "HOME")
    away = create_team(name + "-AWAY", "AWAY")

    status, game, _ = req(
        "POST",
        "/api/games",
        {
            "name": name + "-GAME",
            "home_team_id": home["id"],
            "away_team_id": away["id"],
        },
    )

    check(
        name + " Game creation",
        status == 201,
    )

    status, lifecycle, _ = req(
        "POST",
        f"/api/games/{game['id']}/lifecycle",
        {},
    )

    check(
        name + " lifecycle creation",
        status == 201,
    )

    status, clock, _ = req(
        "POST",
        f"/api/games/{game['id']}/clock",
        {
            "mode": "count_up",
            "duration_seconds": 2700,
        },
    )

    check(
        name + " clock creation",
        status == 201,
    )

    return game, lifecycle, clock


def transition(game_id, action, lv, cv, allow=False):
    return req(
        "POST",
        f"/api/games/{game_id}/lifecycle/transition",
        {
            "action": action,
            "expected_lifecycle_version": lv,
            "expected_clock_version": cv,
        },
        allow=allow,
    )


game, _, _ = setup_game(prefix + "-MAIN")

status, page, content_type = req(
    "GET",
    f"/control/games/{game['id']}",
)

check(
    "Control Center page returns 200",
    status == 200,
)

check(
    "Control Center is HTML",
    "text/html" in content_type.lower(),
)

# Forward-compatible historical regression:
# The current Control Center may identify as M10-D, M10-E, or a later
# milestone. M10-C only owns the lifecycle-control capability.
check(
    "Control Center preserves M10-C lifecycle-control capability",
    all(
        marker in page
        for marker in (
            'data-action="start_first_half"',
            'data-action="end_first_half"',
            'data-action="start_second_half"',
            'data-action="end_game"',
        )
    ),
)

for marker, label in [
    ('data-action="start_first_half"', "Start First Half button present"),
    ('data-action="end_first_half"', "End First Half button present"),
    ('data-action="start_second_half"', "Start Second Half button present"),
    ('data-action="end_game"', "End Game button present"),
]:
    check(
        label,
        marker in page,
    )

_, api_module, _ = req(
    "GET",
    "/static/js/control/api.js",
)

check(
    "M10-C uses integrated lifecycle transition endpoint",
    "/lifecycle/transition" in api_module,
)

check(
    "M10-C sends expected lifecycle version",
    "expected_lifecycle_version" in api_module,
)

check(
    "M10-C sends expected clock version",
    "expected_clock_version" in api_module,
)

_, control_module, _ = req(
    "GET",
    "/static/js/control/control.js",
)

_, socket_module, _ = req(
    "GET",
    "/static/js/control/socket.js",
)

check(
    "M10-C maps phase to lifecycle action",
    "LIFECYCLE_ACTION_BY_PHASE" in control_module,
)

check(
    "M10-C guards in-flight command",
    "commandInFlight" in control_module,
)

check(
    "M10-C handles 409 conflict",
    "error?.status === 409" in control_module,
)

check(
    "M10-C conflict does not auto-retry",
    "command was not retried" in control_module,
)

check(
    "M10-C refreshes authoritative state after conflict",
    "fetchAuthoritativeState" in control_module,
)

# Do NOT assert that scoring UI is absent here. M10-D intentionally added
# scoring controls. Historical M10-C regression must prove that the lifecycle
# behavior remains intact after later milestones extend the Control Center.
check(
    "M10-C lifecycle capability remains intact after later UI milestones",
    all(
        action in control_module
        for action in (
            "start_first_half",
            "end_first_half",
            "start_second_half",
            "end_game",
        )
    ),
)

check(
    "M10-C preserves local clock rendering",
    "setInterval" in control_module
    and "renderClock" in control_module,
)

# The actual event-consumption module is socket.js.
# control.js may mention the string "clock:tick" in a comment explaining
# that it is intentionally not used. That is not consumption.
check(
    "M10-C does not consume clock:tick",
    "clock:tick" not in socket_module,
)

status, r, _ = transition(
    game["id"],
    "start_first_half",
    1,
    1,
)

check("start_first_half returns 200", status == 200)

check(
    "phase becomes first_half",
    r["lifecycle"]["phase"] == "first_half",
)

check(
    "clock becomes running",
    r["clock"]["status"] == "running",
)

lv = r["lifecycle"]["version"]
cv = r["clock"]["version"]

status, r, _ = transition(
    game["id"],
    "end_first_half",
    lv,
    cv,
)

check("end_first_half returns 200", status == 200)

check(
    "phase becomes halftime",
    r["lifecycle"]["phase"] == "halftime",
)

check(
    "clock becomes paused",
    r["clock"]["status"] == "paused",
)

lv = r["lifecycle"]["version"]
cv = r["clock"]["version"]

status, r, _ = transition(
    game["id"],
    "start_second_half",
    lv,
    cv,
)

check(
    "start_second_half returns 200",
    status == 200,
)

check(
    "phase becomes second_half",
    r["lifecycle"]["phase"] == "second_half",
)

check(
    "clock becomes running for second half",
    r["clock"]["status"] == "running",
)

check(
    "second half elapsed base is 2700",
    r["clock"]["elapsed_seconds"] == 2700,
)

lv = r["lifecycle"]["version"]
cv = r["clock"]["version"]

status, r, _ = transition(
    game["id"],
    "end_game",
    lv,
    cv,
)

check(
    "end_game returns 200",
    status == 200,
)

check(
    "phase becomes full_time",
    r["lifecycle"]["phase"] == "full_time",
)

check(
    "clock becomes paused at full time",
    r["clock"]["status"] == "paused",
)

conflict_game, _, _ = setup_game(prefix + "-CONFLICT")

status, _, _ = transition(
    conflict_game["id"],
    "start_first_half",
    1,
    1,
)

check(
    "conflict setup winner returns 200",
    status == 200,
)

status, _, _ = transition(
    conflict_game["id"],
    "start_first_half",
    1,
    1,
    allow=True,
)

check(
    "stale browser-style lifecycle command returns 409",
    status == 409,
)

_, lifecycle_now, _ = req(
    "GET",
    f"/api/games/{conflict_game['id']}/lifecycle",
)

_, clock_now, _ = req(
    "GET",
    f"/api/games/{conflict_game['id']}/clock",
)

check(
    "authoritative lifecycle remains first_half after stale command",
    lifecycle_now["phase"] == "first_half",
)

check(
    "authoritative clock remains running after stale command",
    clock_now["status"] == "running",
)

race_game, _, _ = setup_game(prefix + "-RACE")


def same_transition():
    return transition(
        race_game["id"],
        "start_first_half",
        1,
        1,
        allow=True,
    )


with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results = [
        future.result()
        for future in [
            pool.submit(same_transition),
            pool.submit(same_transition),
        ]
    ]

statuses = sorted(
    result[0]
    for result in results
)

check(
    "two controllers same version produce one 200 / one 409",
    statuses == [200, 409],
)

_, final_lifecycle, _ = req(
    "GET",
    f"/api/games/{race_game['id']}/lifecycle",
)

_, final_clock, _ = req(
    "GET",
    f"/api/games/{race_game['id']}/clock",
)

check(
    "race lifecycle version increments once",
    final_lifecycle["version"] == 2,
)

check(
    "race clock version increments once",
    final_clock["version"] == 2,
)

check(
    "race final state consistent",
    final_lifecycle["phase"] == "first_half"
    and final_clock["status"] == "running",
)

print("========================================")
print(
    f"M10-C Python Tests Passed: "
    f"{passed} Failed: {failed}"
)
print("========================================")

sys.exit(1 if failed else 0)
PY

RC=$?

set -e

cat "$TMP"

P=$(grep -oP 'M10-C Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)

PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))

rm -f "$TMP"

[ "$RC" -eq 0 ] \
    && pass "M10-C lifecycle-control process passed" \
    || fail "M10-C lifecycle-control process failed"

echo ""
echo "========================================"
echo "Running M10-B regression"
echo "========================================"

set +e

BASE_URL="$BASE_URL" \
    ./scripts/validate_m10b.sh

M10B_RC=$?

set -e

[ "$M10B_RC" -eq 0 ] \
    && pass "M10-B regression passed" \
    || fail "M10-B regression failed"

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "M10-C VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M10-C VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi
