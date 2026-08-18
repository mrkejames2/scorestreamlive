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
echo "ScoreStreamLive M11-C Broadcast Clock Precision Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /health/live \
  /health/ready \
  /info \
  /static/vendor/socket.io.min.js \
  /static/js/overlay/overlay.js
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
        print(f"[PASS] {label}", flush=True)
        p+=1
    else:
        print(f"[FAIL] {label}", flush=True)
        f+=1

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

home=req("POST","/api/teams",{"name":f"M11C-P Home {stamp}","short_name":"HOME"})[1]
away=req("POST","/api/teams",{"name":f"M11C-P Away {stamp}","short_name":"AWAY"})[1]
game=req("POST","/api/games",{
    "name":f"M11C Precision {stamp}",
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
check("M11-B Socket.IO browser client preserved","socket.io" in page.lower())

_,js,_=req("GET","/static/js/overlay/overlay.js")

check("M11-C uses monotonic performance clock","performance.now()" in js)
check(
    "M11-C does not anchor interpolation with Date.now",
    "clockAnchorClientMs = Date.now()" not in js
    and "clockAnchorPerformanceMs = Date.now()" not in js
    and "Date.now() - state.clockAnchor" not in js,
)
check(
    "M11-C precision resync interval is 5 seconds",
    "CLOCK_RESYNC_MS = 5000" in js,
)
check(
    "M11-C has dedicated clock-only authoritative resync",
    "resyncAuthoritativeClock" in js
    and f"/api/games/${{gameId}}/clock" in js,
)
check(
    "M11-C clock-only resync replaces only clock state",
    "state.clock = clock" in js
    and "captureClockAnchor(clock)" in js,
)
check(
    "M11-C full recovery remains available",
    "recoverAuthoritativeState" in js
    and "loadAuthoritativeState" in js,
)
check(
    "M11-C recovers after browser visibility resumes",
    "visibilitychange" in js
    and "document.visibilityState" in js,
)
check(
    "M11-C preserves local quarter-second visual rendering",
    "setInterval(render, 250)" in js,
)
check(
    "M11-C preserves Socket.IO live synchronization",
    'socket.on("connect"' in js
    and "game:score_updated" in js
    and "clock:updated" in js,
)
check(
    "M11-C remains read-only",
    'method: "POST"' not in js
    and "method: 'POST'" not in js,
)
check(
    "M11-C has no clock tick consumer",
    'socket.on("clock:tick"' not in js
    and "socket.on('clock:tick'" not in js,
)

status,transition,_=req(
    "POST",
    f"/api/games/{game['id']}/lifecycle/transition",
    {
        "action":"start_first_half",
        "expected_lifecycle_version":1,
        "expected_clock_version":1,
    },
)
check("First-half transition returns 200",status==200)

time.sleep(2)

_,clock,_=req("GET",f"/api/games/{game['id']}/clock")
check(
    "Authoritative elapsed advances while running",
    clock["status"]=="running"
    and clock["authoritative_elapsed_seconds"] >= 2,
)

print("========================================")
print(f"M11-C Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY

RC=$?
set -e

cat "$TMP"
P=$(grep -oP 'M11-C Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M11-C precision process passed" \
  || fail "M11-C precision process failed"

echo ""
echo "========================================"
echo "Running M11-B regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m11b.sh
B_RC=$?
set -e

[ "$B_RC" -eq 0 ] \
  && pass "M11-B regression passed" \
  || fail "M11-B regression failed"

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo "M11-C VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M11-C VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
