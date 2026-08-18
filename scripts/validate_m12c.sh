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
echo "ScoreStreamLive M12-C Game Initialization + Launch Readiness"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /health/live \
  /health/ready \
  /info \
  /games \
  /static/js/games/index.js
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

PAGE=$(curl -fsS "${BASE_URL}/games")
JS=$(curl -fsS "${BASE_URL}/static/js/games/index.js")

# M12-C introduced launch-ready Game creation. Later milestones may change
# presentation labels, so validate the enduring capability rather than a
# literal "M12-C" page marker.
grep -Fq 'Create Game' <<<"$PAGE" \
  && grep -Fq 'new-game-form' <<<"$PAGE" \
  && grep -Fq 'Create Game' <<<"$JS" \
  && pass "M12-C launch-ready Game Setup capability preserved" \
  || fail "M12-C launch-ready Game Setup capability missing"

grep -Fq 'ensureLifecycleInitialized' <<<"$JS" \
  && pass "Lifecycle initialization orchestration exists" \
  || fail "Lifecycle initialization orchestration missing"

grep -Fq 'ensureClockInitialized' <<<"$JS" \
  && pass "Clock initialization orchestration exists" \
  || fail "Clock initialization orchestration missing"

grep -Fq 'initializeCreatedGame' <<<"$JS" \
  && pass "Launch-readiness orchestration exists" \
  || fail "Launch-readiness orchestration missing"

grep -Fq 'payload: {}' <<<"$JS" \
  && pass "Lifecycle creation uses existing empty payload contract" \
  || fail "Lifecycle create payload contract missing"

grep -Fq 'mode: "count_up"' <<<"$JS" \
  && pass "Clock initializes count-up mode" \
  || fail "Count-up clock initialization missing"

grep -Fq 'duration_seconds: 2700' <<<"$JS" \
  && pass "Clock initializes 45-minute duration" \
  || fail "45-minute duration missing"

grep -Fq 'verifiedLifecycle?.phase !== "pregame"' <<<"$JS" \
  && pass "Lifecycle initialization is verified" \
  || fail "Lifecycle verification missing"

grep -Fq 'verifiedClock?.status === "running"' <<<"$JS" \
  && pass "Clock is verified not to auto-start" \
  || fail "Stopped-clock verification missing"

grep -Fq 'Game ready:' <<<"$JS" \
  && pass "UI reports launch-ready Game" \
  || fail "Launch-ready success message missing"

# Preserve M12-A scalability.
grep -Fq 'const MAX_VISIBLE_GAMES = 25;' <<<"$JS" \
  && pass "M12-A recent-game cap preserved" \
  || fail "M12-A recent-game cap regressed"

grep -Fq 'const MAX_CONCURRENT_GAMES = 6;' <<<"$JS" \
  && pass "M12-A bounded concurrency preserved" \
  || fail "M12-A bounded concurrency regressed"

if grep -Fq 'clock:tick' <<<"$JS"; then
  fail "clock:tick consumer introduced"
else
  pass "No clock:tick consumer introduced"
fi

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
    data=None
    headers={}
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
    "name":f"M12C Home {stamp}",
    "short_name":"C-H",
})[1]

away=req("POST","/api/teams",{
    "name":f"M12C Away {stamp}",
    "short_name":"C-A",
})[1]

game=req("POST","/api/games",{
    "name":f"M12-C Launch Ready {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]

lifecycle=req("POST",f"/api/games/{game['id']}/lifecycle",{})[1]
clock=req("POST",f"/api/games/{game['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})[1]

check("Lifecycle initializes pregame",lifecycle.get("phase")=="pregame")
check("Clock initializes count_up",clock.get("mode")=="count_up")
check("Clock initializes stopped",clock.get("status")=="stopped")
check("Clock initializes duration 2700",clock.get("duration_seconds")==2700)
check("Clock initializes elapsed 0",clock.get("elapsed_seconds")==0)

fresh_lifecycle=req("GET",f"/api/games/{game['id']}/lifecycle")[1]
fresh_clock=req("GET",f"/api/games/{game['id']}/clock")[1]

check("Lifecycle GET verifies pregame",fresh_lifecycle.get("phase")=="pregame")
check("Clock GET verifies stopped",fresh_clock.get("status")=="stopped")
check("Clock GET verifies count_up",fresh_clock.get("mode")=="count_up")
check("Clock GET verifies duration",fresh_clock.get("duration_seconds")==2700)

control_status,control_page,control_ct=req("GET",f"/control/games/{game['id']}")
overlay_status,overlay_page,overlay_ct=req("GET",f"/overlay/games/{game['id']}")

check("Control Center route opens",control_status==200 and "text/html" in control_ct.lower())
check("Overlay route opens",overlay_status==200 and "text/html" in overlay_ct.lower())

fresh_game=req("GET",f"/api/games/{game['id']}")[1]
check("Game remains authoritative 0-0",
      fresh_game.get("home_score")==0 and fresh_game.get("away_score")==0)

print("========================================")
print(f"M12-C Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY

RC=$?
set -e
cat "$TMP"

P=$(grep -oP 'M12-C Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M12-C initialization process passed" \
  || fail "M12-C initialization process failed"

echo ""
echo "========================================"
echo "Running M12-B regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12b.sh
M12B_RC=$?
set -e

[ "$M12B_RC" -eq 0 ] \
  && pass "M12-B regression passed" \
  || fail "M12-B regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M12-C VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M12-C VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi