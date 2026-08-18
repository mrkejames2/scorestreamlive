#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"
export BASE_URL

PASS=0
FAIL=0

pass(){
  echo "[PASS] $1"
  PASS=$((PASS+1))
}

fail(){
  echo "[FAIL] $1"
  FAIL=$((FAIL+1))
}

echo "========================================"
echo "ScoreStreamLive M11-E Goal Presentation Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /health/live \
  /health/ready \
  /info \
  /static/css/overlay.css \
  /static/js/overlay/overlay.js \
  /static/vendor/socket.io.min.js
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)

  if [ "$code" = "200" ]; then
    pass "$path"
  else
    fail "$path HTTP ${code}"
  fi
done

TMP=$(mktemp)

set +e

docker compose exec -T -e BASE_URL="$BASE_URL" app python3 - <<'PY' >"$TMP" 2>&1
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = os.environ["BASE_URL"]
stamp = int(time.time())

p = 0
f = 0


def check(label, condition):
    global p, f

    if condition:
        print(f"[PASS] {label}", flush=True)
        p += 1
    else:
        print(f"[FAIL] {label}", flush=True)
        f += 1


def req(method, path, payload=None):
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

            if raw and "application/json" in content_type.lower():
                body = json.loads(raw)
            else:
                body = raw.decode(errors="replace")

            return response.status, body, content_type

    except urllib.error.HTTPError as exc:
        raw = exc.read()

        try:
            error_body = json.loads(raw) if raw else None
        except Exception:
            error_body = raw.decode(errors="replace")

        print(
            f"[ERROR] {method} {path} returned HTTP {exc.code}",
            flush=True,
        )
        print(
            f"[ERROR] Response: {error_body}",
            flush=True,
        )

        raise


# ------------------------------------------------------------
# Test data
# ------------------------------------------------------------

home = req(
    "POST",
    "/api/teams",
    {
        "name": "Saginaw United",
        "short_name": "SAG",
    },
)[1]

away = req(
    "POST",
    "/api/teams",
    {
        "name": "Midland City",
        "short_name": "MID",
    },
)[1]

game = req(
    "POST",
    "/api/games",
    {
        "name": f"M11E Goal Presentation {stamp}",
        "home_team_id": home["id"],
        "away_team_id": away["id"],
    },
)[1]

req(
    "POST",
    f"/api/games/{game['id']}/lifecycle",
    {},
)

req(
    "POST",
    f"/api/games/{game['id']}/clock",
    {
        "mode": "count_up",
        "duration_seconds": 2700,
    },
)

# IMPORTANT:
# Player creation uses the established /api/players endpoint.
player = req(
    "POST",
    "/api/players",
    {
        "team_id": home["id"],
        "first_name": "Maverick",
        "last_name": "James",
        "jersey_number": 10,
    },
)[1]


# ------------------------------------------------------------
# Overlay HTML
# ------------------------------------------------------------

_, page, content_type = req(
    "GET",
    f"/overlay/games/{game['id']}",
)

check(
    "Overlay returns HTML",
    "text/html" in content_type.lower(),
)

check(
    "M11-E goal banner shell present",
    'id="goal-banner"' in page,
)

check(
    "M11-E goal team field present",
    'id="goal-team-name"' in page,
)

check(
    "M11-E scorer field present",
    'id="goal-scorer-name"' in page,
)

check(
    "M11-E scoring minute field present",
    'id="goal-minute"' in page,
)

check(
    "M11-D broadcast scoreboard preserved",
    'id="overlay-scoreboard"' in page,
)


# ------------------------------------------------------------
# Overlay CSS
# ------------------------------------------------------------

_, css, _ = req(
    "GET",
    "/static/css/overlay.css",
)

check(
    "M11-E goal banner styling exists",
    ".goal-banner" in css,
)

check(
    "M11-E goal banner entry animation exists",
    "goal-banner-in" in css,
)

check(
    "M11-E goal banner exit animation exists",
    "goal-banner-out" in css,
)

check(
    "M11-D transparent canvas preserved",
    "background: transparent" in css,
)


# ------------------------------------------------------------
# Overlay JavaScript
# ------------------------------------------------------------

_, js, _ = req(
    "GET",
    "/static/js/overlay/overlay.js",
)

check(
    "M11-E listens for scoring_event:created",
    'socket.on("scoring_event:created"' in js,
)

check(
    "M11-E renders goal banner",
    "showGoalBanner" in js,
)

check(
    "M11-E auto-clears goal banner",
    "GOAL_BANNER_VISIBLE_MS = 5000" in js,
)

check(
    "M11-E formats scoring minute",
    "game_elapsed_seconds" in js
    and "scoringMinute" in js,
)

check(
    "M11-E resolves scorer from roster",
    "playerDisplayName" in js,
)

check(
    "M11-E handles null scorer",
    "TEAM GOAL" in js,
)

check(
    "M11-E avoids duplicate goal event presentation",
    "lastGoalEventId" in js,
)

check(
    "M11-E refreshes authoritative state after scoring",
    "recoverAuthoritativeState" in js,
)

check(
    "M11-C 5-second clock precision preserved",
    "CLOCK_RESYNC_MS = 5000" in js,
)

check(
    "M11-D last-known recovery behavior preserved",
    "hasAuthoritativeState" in js,
)

check(
    "Overlay remains read-only",
    'method: "POST"' not in js
    and "method: 'POST'" not in js,
)

check(
    "Overlay consumes no clock tick",
    'socket.on("clock:tick"' not in js
    and "socket.on('clock:tick'" not in js,
)


# ------------------------------------------------------------
# Dynamic goal presentation contract
# ------------------------------------------------------------

transition = req(
    "POST",
    f"/api/games/{game['id']}/lifecycle/transition",
    {
        "action": "start_first_half",
        "expected_lifecycle_version": 1,
        "expected_clock_version": 1,
    },
)[1]

check(
    "First half starts successfully",
    transition["lifecycle"]["phase"] == "first_half"
    and transition["clock"]["status"] == "running",
)

time.sleep(2)

goal = req(
    "POST",
    "/api/scoring-events",
    {
        "game_id": game["id"],
        "team_id": home["id"],
        "player_id": player["id"],
        "event_type": "goal",
    },
)[1]

check(
    "Goal REST creation succeeds",
    goal["event_type"] == "goal",
)

check(
    "Goal REST includes player id",
    goal.get("player_id") == player["id"],
)

check(
    "Goal REST includes game_elapsed_seconds",
    isinstance(goal.get("game_elapsed_seconds"), int),
)

check(
    "Goal elapsed time is nonnegative",
    goal.get("game_elapsed_seconds", -1) >= 0,
)

_, fresh_game, _ = req(
    "GET",
    f"/api/games/{game['id']}",
)

check(
    "Authoritative score increments",
    fresh_game["home_score"] == 1,
)

print("========================================")
print(f"M11-E Python Tests Passed: {p} Failed: {f}")
print("========================================")

sys.exit(1 if f else 0)
PY

RC=$?

set -e

cat "$TMP"

P=$(grep -oP 'M11-E Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)

PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))

rm -f "$TMP"

if [ "$RC" -eq 0 ]; then
  pass "M11-E goal-presentation process passed"
else
  fail "M11-E goal-presentation process failed"
fi

echo ""
echo "========================================"
echo "Running M11-D regression"
echo "========================================"

set +e

BASE_URL="$BASE_URL" ./scripts/validate_m11d.sh
M11D_RC=$?

set -e

if [ "$M11D_RC" -eq 0 ]; then
  pass "M11-D regression passed"
else
  fail "M11-D regression failed"
fi

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo "M11-E VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M11-E VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi