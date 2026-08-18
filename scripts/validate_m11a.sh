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
echo "ScoreStreamLive M11-A Read-Only Overlay Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path"
done

TMP=$(mktemp)
set +e
docker compose exec -T -e BASE_URL="$BASE_URL" app python3 - <<'PY' >"$TMP" 2>&1
import json, os, sys, time, urllib.request

BASE=os.environ["BASE_URL"]
stamp=int(time.time())
p=f=0

def check(label,cond):
    global p,f
    if cond:
        print(f"[PASS] {label}",flush=True); p+=1
    else:
        print(f"[FAIL] {label}",flush=True); f+=1

def req(method,path,payload=None):
    data=None; headers={}
    if payload is not None:
        data=json.dumps(payload).encode()
        headers["Content-Type"]="application/json"
    request=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)
    with urllib.request.urlopen(request,timeout=15) as response:
        raw=response.read()
        ct=response.headers.get("Content-Type","")
        body=json.loads(raw) if raw and "application/json" in ct.lower() else raw.decode(errors="replace")
        return response.status,body,ct

home=req("POST","/api/teams",{"name":f"M11A Home {stamp}","short_name":"HOME"})[1]
away=req("POST","/api/teams",{"name":f"M11A Away {stamp}","short_name":"AWAY"})[1]
game=req("POST","/api/games",{
    "name":f"M11A Overlay {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]
req("POST",f"/api/games/{game['id']}/lifecycle",{})
req("POST",f"/api/games/{game['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})

status,page,ct=req("GET",f"/overlay/games/{game['id']}")
check("Overlay route returns 200",status==200)
check("Overlay route returns HTML","text/html" in ct.lower())
check("Overlay contains scoreboard shell",'id="overlay-scoreboard"' in page)
check("Overlay contains home team field",'id="home-team-name"' in page)
check("Overlay contains away team field",'id="away-team-name"' in page)
check("Overlay contains score fields",'id="home-score"' in page and 'id="away-score"' in page)
check("Overlay contains clock field",'id="clock-display"' in page)
check("Overlay contains phase field",'id="phase-display"' in page)
check("Overlay loads dedicated CSS",'/static/css/overlay.css' in page)
check("Overlay loads dedicated JS",'/static/js/overlay/overlay.js' in page)

_,css,_=req("GET","/static/css/overlay.css")
check("Overlay background is transparent","background: transparent" in css)
check(
    "Overlay is broadcast-positioned",
    ".overlay-scoreboard" in css
    and "position: absolute" in css
    and "left: 50%" in css
    and "bottom:" in css
    and "transform: translateX(-50%)" in css
)
check("Overlay supports responsive fallback","@media (max-width: 900px)" in css)

_,js,_=req("GET","/static/js/overlay/overlay.js")
check("Overlay reads Game REST state",f"/api/games/" in js)
check("Overlay reads Team REST state","/api/teams/" in js)
check("Overlay reads lifecycle REST state","/lifecycle" in js)
check("Overlay reads clock REST state","/clock" in js)
check("Overlay renders local interpolated clock","setInterval(render, 250)" in js)
check(
    "M11-A read-only overlay capability preserved",
    "loadAuthoritativeState" in js
    and "/api/games/" in js
)
check(
    "M11-A has no mutation fetch",
    'method: "POST"' not in js and "method: 'POST'" not in js
)
check(
    "M11-A consumes no clock:tick",
    'socket.on("clock:tick"' not in js
    and "socket.on('clock:tick'" not in js
)

print("========================================")
print(f"M11-A Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY
RC=$?
set -e

cat "$TMP"
P=$(grep -oP 'M11-A Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M11-A overlay process passed" \
  || fail "M11-A overlay process failed"

echo ""
echo "========================================"
echo "Running Milestone 10 final regression gate"
echo "========================================"
set +e
BASE_URL="$BASE_URL" ./scripts/validate_m10h.sh
M10_RC=$?
set -e

[ "$M10_RC" -eq 0 ] \
  && pass "Milestone 10 regression passed" \
  || fail "Milestone 10 regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M11-A VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M11-A VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
