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
echo "ScoreStreamLive M11-D Broadcast Presentation Validation"
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

h=req("POST","/api/teams",{"name":f"M11D Home {stamp}","short_name":"HOME"})[1]
a=req("POST","/api/teams",{"name":f"M11D Away {stamp}","short_name":"AWAY"})[1]
g=req("POST","/api/games",{
    "name":f"M11D Presentation {stamp}",
    "home_team_id":h["id"],
    "away_team_id":a["id"],
})[1]

req("POST",f"/api/games/{g['id']}/lifecycle",{})
req("POST",f"/api/games/{g['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})

_,page,ct=req("GET",f"/overlay/games/{g['id']}")
check("Overlay returns HTML","text/html" in ct.lower())
check("M11-D branded rail present","brand-rail" in page and "brand-mark" in page)
check("M11-D home/away presentation labels present","team-label" in page)
check("M11-D live status badge present",'id="overlay-status-badge"' in page)
check("M11-D scoreboard shell preserved",'id="overlay-scoreboard"' in page)
check("M11-D Socket.IO client preserved","socket.io" in page.lower())

_,css,_=req("GET","/static/css/overlay.css")
check("Overlay page remains transparent","background: transparent" in css)
check("M11-D broadcast scoreboard styling exists",".overlay-scoreboard" in css)
check("M11-D score typography is prominent","font-size: 50px" in css)
check("M11-D clock typography is prominent","font-size: 40px" in css)
check("M11-D includes 720p layout breakpoint","@media (max-width: 1280px)" in css)
check("M11-D includes narrower preview breakpoint","@media (max-width: 900px)" in css)
check("M11-D recovery styling exists",".overlay-recovering" in css)
check("M11-D error surface is presentation-safe",".overlay-error" in css)

_,js,_=req("GET","/static/js/overlay/overlay.js")
check("M11-D preserves 5-second clock resync","CLOCK_RESYNC_MS = 5000" in js)
check("M11-D preserves monotonic clock","performance.now()" in js)
check("M11-D preserves Socket.IO live sync",'socket.on("connect"' in js)
check("M11-D preserves authoritative recovery","recoverAuthoritativeState" in js)
check("M11-D keeps last-known state on recovery failure",
      "if (!state.hasAuthoritativeState)" in js)
check("M11-D exposes connection presentation state",
      "setPresentationConnectionState" in js)
check("M11-D remains read-only",
      'method: "POST"' not in js and "method: 'POST'" not in js)
check("M11-D has no clock tick consumer",
      'socket.on("clock:tick"' not in js and "socket.on('clock:tick'" not in js)

print("========================================")
print(f"M11-D Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY

RC=$?
set -e

cat "$TMP"
P=$(grep -oP 'M11-D Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M11-D presentation process passed" \
  || fail "M11-D presentation process failed"

echo ""
echo "========================================"
echo "Running M11-C regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m11c.sh
C_RC=$?
set -e

[ "$C_RC" -eq 0 ] \
  && pass "M11-C regression passed" \
  || fail "M11-C regression failed"

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo "M11-D VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M11-D VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
