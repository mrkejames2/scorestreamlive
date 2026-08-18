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
echo "ScoreStreamLive M11-F Match-State Presentation Validation"
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
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

TMP=$(mktemp)
set +e

docker compose exec -T -e BASE_URL="$BASE_URL" app python3 - <<'PY' >"$TMP" 2>&1
import json
import os
import sys
import time
import urllib.request

BASE=os.environ["BASE_URL"]
stamp=int(time.time())
p=f=0

def check(label, cond):
    global p,f
    if cond:
        print(f"[PASS] {label}", flush=True); p+=1
    else:
        print(f"[FAIL] {label}", flush=True); f+=1

def req(method,path,payload=None):
    data=None; headers={}
    if payload is not None:
        data=json.dumps(payload).encode()
        headers["Content-Type"]="application/json"

    r=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)

    with urllib.request.urlopen(r,timeout=15) as x:
        raw=x.read()
        ct=x.headers.get("Content-Type","")
        body=json.loads(raw) if raw and "application/json" in ct.lower() else raw.decode(errors="replace")
        return x.status,body,ct

home=req("POST","/api/teams",{
    "name":"Saginaw United",
    "short_name":"SAG",
})[1]

away=req("POST","/api/teams",{
    "name":"Midland City",
    "short_name":"MID",
})[1]

game=req("POST","/api/games",{
    "name":f"M11F Match State {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]

req("POST",f"/api/games/{game['id']}/lifecycle",{})
req("POST",f"/api/games/{game['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})

_,page,ct=req("GET",f"/overlay/games/{game['id']}")

check("Overlay returns HTML","text/html" in ct.lower())
check("M11-F match-state banner shell present",'id="match-state-banner"' in page)
check("M11-F match-state title field present",'id="match-state-title"' in page)
check("M11-F match-state scoreline field present",'id="match-state-scoreline"' in page)
check("M11-E goal banner preserved",'id="goal-banner"' in page)
check("M11-D scoreboard preserved",'id="overlay-scoreboard"' in page)

_,css,_=req("GET","/static/css/overlay.css")
check("M11-F match-state styling exists",".match-state-banner" in css)
check("M11-F match-state entry animation exists","match-state-in" in css)
check("M11-F match-state exit animation exists","match-state-out" in css)
check("M11-E goal styling preserved",".goal-banner" in css)
check("Transparent broadcast canvas preserved","background: transparent" in css)

_,js,_=req("GET","/static/js/overlay/overlay.js")
check("M11-F auto-clears match-state banner",
      "MATCH_STATE_BANNER_VISIBLE_MS = 5000" in js)
check("M11-F has phase-title mapping","matchStateTitle" in js)
check("M11-F renders authoritative scoreline","matchStateScoreline" in js)
check("M11-F avoids duplicate phase presentation","lastPresentedPhase" in js)
check("M11-F does not replay lifecycle banner on bootstrap",
      "Do not present a lifecycle banner simply because the page loaded." in js)
check("M11-F lifecycle presentation handler exists","applyLifecyclePresentation" in js)
check("M11-F listens for lifecycle committed-state events",
      'socket.on("game:lifecycle_updated"' in js
      and 'socket.on("lifecycle:updated"' in js
      and 'socket.on("game:phase_updated"' in js)
check("M11-E scoring_event goal banner preserved",
      'socket.on("scoring_event:created"' in js
      and "showGoalBanner" in js)
check("M11-C precision resync preserved","CLOCK_RESYNC_MS = 5000" in js)
check("M11-C monotonic clock preserved","performance.now()" in js)
check("M11-D last-known recovery preserved","hasAuthoritativeState" in js)
check("Overlay remains read-only",
      'method: "POST"' not in js and "method: 'POST'" not in js)
check("Overlay consumes no clock tick",
      'socket.on("clock:tick"' not in js and "socket.on('clock:tick'" not in js)

# Dynamic lifecycle contract: verify authoritative phases/scores.
r=req(
    "POST",
    f"/api/games/{game['id']}/lifecycle/transition",
    {
        "action":"start_first_half",
        "expected_lifecycle_version":1,
        "expected_clock_version":1,
    },
)[1]

check("First-half transition succeeds",
      r["lifecycle"]["phase"]=="first_half"
      and r["clock"]["status"]=="running")

time.sleep(1)

r=req(
    "POST",
    f"/api/games/{game['id']}/lifecycle/transition",
    {
        "action":"end_first_half",
        "expected_lifecycle_version":r["lifecycle"]["version"],
        "expected_clock_version":r["clock"]["version"],
    },
)[1]

check("Halftime transition succeeds",
      r["lifecycle"]["phase"]=="halftime"
      and r["clock"]["status"]=="paused")

r=req(
    "POST",
    f"/api/games/{game['id']}/lifecycle/transition",
    {
        "action":"start_second_half",
        "expected_lifecycle_version":r["lifecycle"]["version"],
        "expected_clock_version":r["clock"]["version"],
    },
)[1]

check("Second-half transition succeeds",
      r["lifecycle"]["phase"]=="second_half"
      and r["clock"]["status"]=="running")

r=req(
    "POST",
    f"/api/games/{game['id']}/lifecycle/transition",
    {
        "action":"end_game",
        "expected_lifecycle_version":r["lifecycle"]["version"],
        "expected_clock_version":r["clock"]["version"],
    },
)[1]

check("Full-time transition succeeds",
      r["lifecycle"]["phase"]=="full_time"
      and r["clock"]["status"]=="paused")

_,fresh,_=req("GET",f"/api/games/{game['id']}")
check("Authoritative final score remains available",
      isinstance(fresh.get("home_score"), int)
      and isinstance(fresh.get("away_score"), int))

print("========================================")
print(f"M11-F Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY

RC=$?
set -e

cat "$TMP"

P=$(grep -oP 'M11-F Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)

PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))

rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M11-F match-state process passed" \
  || fail "M11-F match-state process failed"

echo ""
echo "========================================"
echo "Running M11-E regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m11e.sh
E_RC=$?
set -e

[ "$E_RC" -eq 0 ] \
  && pass "M11-E regression passed" \
  || fail "M11-E regression failed"

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo "M11-F VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M11-F VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
