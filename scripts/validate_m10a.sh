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
echo "ScoreStreamLive M10-A Regression Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)

    [ "$code" = "200" ] \
        && pass "$path" \
        || fail "$path"
done

TMP=$(mktemp)

set +e

BASE_URL="$BASE_URL" python3 - <<'PY' >"$TMP" 2>&1
import json
import os
import sys
import time
import urllib.error
import urllib.request

base = os.environ["BASE_URL"]
prefix = f"M10A-REG-{int(time.time())}"

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


def request(method, path, payload=None, allow_error=False):
    data = None
    headers = {}

    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(
        base + path,
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            raw = response.read()
            content_type = response.headers.get("Content-Type", "")

            if raw:
                if "application/json" in content_type.lower():
                    body = json.loads(raw)
                else:
                    body = raw.decode("utf-8", errors="replace")
            else:
                body = None

            normalized_headers = {
                key.lower(): value
                for key, value in response.headers.items()
            }

            return response.status, body, normalized_headers

    except urllib.error.HTTPError as exc:
        raw = exc.read()

        if not allow_error:
            raise

        normalized_headers = {
            key.lower(): value
            for key, value in exc.headers.items()
        }

        body = raw.decode("utf-8", errors="replace") if raw else None

        return exc.code, body, normalized_headers


def create_team(name, short_name):
    status, body, _ = request(
        "POST",
        "/api/teams",
        {
            "name": name,
            "short_name": short_name,
        },
    )

    check(f"{short_name} team creation", status == 201)

    return body


home = create_team(prefix + "-HOME", "HOME")
away = create_team(prefix + "-AWAY", "AWAY")

status, game, _ = request(
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

status, _, _ = request(
    "POST",
    f"/api/games/{game_id}/lifecycle",
    {},
)

check("Lifecycle creation", status == 201)

status, _, _ = request(
    "POST",
    f"/api/games/{game_id}/clock",
    {
        "mode": "count_up",
        "duration_seconds": 2700,
    },
)

check("Clock creation", status == 201)

status, _, _ = request(
    "POST",
    "/api/players",
    {
        "team_id": home["id"],
        "first_name": "Home",
        "last_name": "Player",
        "jersey_number": 17,
    },
)

check("Home player creation", status == 201)

status, _, _ = request(
    "POST",
    "/api/players",
    {
        "team_id": away["id"],
        "first_name": "Away",
        "last_name": "Player",
        "jersey_number": 9,
    },
)

check("Away player creation", status == 201)

status, page, headers = request(
    "GET",
    f"/control/games/{game_id}",
)

check(
    "Control Center page returns 200",
    status == 200,
)

check(
    "Control Center is HTML",
    "text/html" in headers.get("content-type", "").lower(),
)

check(
    "Control Center includes game id",
    game_id in page,
)

check(
    "Control Center includes Game Control title",
    "Game Control" in page,
)

# M10-A regression verifies that the read surface still exists.
# It intentionally does NOT require the page to remain read-only,
# because later M10 checkpoints add controlled mutations.
check(
    "Control Center preserves M10-A read surface",
    all(
        marker in page
        for marker in [
            "home-team-name",
            "away-team-name",
            "home-score",
            "away-score",
            "clock-display",
            "phase-display",
            "home-roster",
            "away-roster",
            "scoring-list",
        ]
    ),
)

for path, label, needles in [
    (
        "/static/css/control.css",
        "Control CSS loads",
        [".scoreboard-card"],
    ),
    (
        "/static/js/control/api.js",
        "Control API module loads",
        ["getGame", "getClock", "getLifecycle", "getScoringEvents"],
    ),
    (
        "/static/js/control/clock.js",
        "Control clock module loads",
        ["displaySeconds", "formatClock", "soccerAddedTimeMinute"],
    ),
    (
        "/static/js/control/state.js",
        "Control state module loads",
        ["replaceState"],
    ),
    (
        "/static/js/control/control.js",
        "Control bootstrap module loads",
        ["fetchAuthoritativeState", "renderClock", "renderStaticState"],
    ),
]:
    status, asset_content, _ = request(
        "GET",
        path,
    )

    check(
        label,
        status == 200
        and all(
            needle in asset_content
            for needle in needles
        ),
    )

read_checks = [
    (f"/api/games/{game_id}", "Game REST read"),
    (f"/api/teams/{home['id']}", "Home Team REST read"),
    (f"/api/teams/{away['id']}", "Away Team REST read"),
    (f"/api/teams/{home['id']}/players", "Home roster REST read"),
    (f"/api/teams/{away['id']}/players", "Away roster REST read"),
    (f"/api/games/{game_id}/lifecycle", "Lifecycle REST read"),
    (f"/api/games/{game_id}/clock", "Clock REST read"),
    (f"/api/games/{game_id}/scoring-events", "Scoring history REST read"),
]

for path, label in read_checks:
    status, _, _ = request(
        "GET",
        path,
    )

    check(
        label,
        status == 200,
    )

# The durable M10-A contract is that the UI can still bootstrap all
# authoritative read state. Later milestones are allowed to add mutations.
_, control_module, _ = request(
    "GET",
    "/static/js/control/control.js",
)

check(
    "Control Center still bootstraps authoritative REST state",
    "fetchAuthoritativeState" in control_module,
)

check(
    "Control Center still renders local clock state",
    "renderClock" in control_module
    and "setInterval" in control_module,
)

print("========================================")
print(
    f"M10-A Regression Tests Passed: "
    f"{passed} Failed: {failed}"
)
print("========================================")

sys.exit(1 if failed else 0)
PY

RC=$?

set -e

cat "$TMP"

P=$(grep -oP 'M10-A Regression Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)

PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))

rm -f "$TMP"

[ "$RC" -eq 0 ] \
    && pass "M10-A Control Center regression process passed" \
    || fail "M10-A Control Center regression process failed"

echo ""
echo "========================================"
echo "Running M9 regression"
echo "========================================"

set +e

BASE_URL="$BASE_URL" \
    ./scripts/validate_m9.sh

M9_RC=$?

set -e

[ "$M9_RC" -eq 0 ] \
    && pass "M9 full regression passed" \
    || fail "M9 full regression failed"

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
    echo "M10-A REGRESSION VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M10-A REGRESSION VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi
