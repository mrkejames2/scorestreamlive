#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"
export BASE_URL
PASS=0; FAIL=0
pass(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
fail(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "========================================"
echo "ScoreStreamLive M11-B Live Overlay Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info /static/vendor/socket.io.min.js /static/js/overlay/overlay.js; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

TMP=$(mktemp)
set +e
docker compose exec -T -e BASE_URL="$BASE_URL" app python3 - <<'PY' >"$TMP" 2>&1
import json, os, sys, time, urllib.request
BASE=os.environ["BASE_URL"]; stamp=int(time.time()); p=f=0

def check(label, cond):
    global p,f
    if cond: print(f"[PASS] {label}",flush=True); p+=1
    else: print(f"[FAIL] {label}",flush=True); f+=1

def req(method,path,payload=None):
    data=None; headers={}
    if payload is not None:
        data=json.dumps(payload).encode(); headers["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)
    with urllib.request.urlopen(r,timeout=15) as x:
        raw=x.read(); ct=x.headers.get("Content-Type","")
        body=json.loads(raw) if raw and "application/json" in ct.lower() else raw.decode(errors="replace")
        return x.status,body,ct

h=req("POST","/api/teams",{"name":f"M11B Home {stamp}","short_name":"HOME"})[1]
a=req("POST","/api/teams",{"name":f"M11B Away {stamp}","short_name":"AWAY"})[1]
g=req("POST","/api/games",{"name":f"M11B Overlay {stamp}","home_team_id":h["id"],"away_team_id":a["id"]})[1]
req("POST",f"/api/games/{g['id']}/lifecycle",{})
req("POST",f"/api/games/{g['id']}/clock",{"mode":"count_up","duration_seconds":2700})

_,page,ct=req("GET",f"/overlay/games/{g['id']}")
check("Overlay returns HTML","text/html" in ct.lower())
check(
    "Overlay loads Socket.IO browser client",
    "socket.io" in page.lower()
)
check("Overlay retains dedicated JS","/static/js/overlay/overlay.js" in page)
check("Overlay remains read-only shell",'id="overlay-scoreboard"' in page)

_,js,_=req("GET","/static/js/overlay/overlay.js")
check("Overlay opens Socket.IO connection","window.io" in js)
check("Overlay handles connect","socket.on(\"connect\"" in js)
check("Overlay handles disconnect","socket.on(\"disconnect\"" in js)
check("Overlay handles reconnect attempts","reconnect_attempt" in js)
check("Overlay filters events by game_id","belongsToThisGame" in js and "eventGameId" in js)
check("Overlay reacts to score updates","game:score_updated" in js)
check("Overlay reacts to scoring events","scoring_event:created" in js)
check("Overlay listens for lifecycle committed-state events","lifecycle:updated" in js or "game:lifecycle_updated" in js)
check("Overlay listens for clock committed-state events","clock:updated" in js or "game:clock_updated" in js)
check("Socket event recovery re-reads authoritative REST state","recoverAuthoritativeState" in js and "loadAuthoritativeState" in js)
check("Reconnect performs authoritative recovery",
      js.find('socket.on("connect"') < js.find("await recoverAuthoritativeState()"))
check("Overlay retains local clock interpolation","setInterval(render, 250)" in js)
check("Overlay has no POST mutation implementation",
      'method: "POST"' not in js and "method: 'POST'" not in js)
check("Overlay consumes no clock tick event",
      'socket.on("clock:tick"' not in js and "socket.on('clock:tick'" not in js)

print("========================================")
print(f"M11-B Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY
RC=$?
set -e
cat "$TMP"
P=$(grep -oP 'M11-B Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0})); FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"
[ "$RC" -eq 0 ] && pass "M11-B live overlay process passed" || fail "M11-B live overlay process failed"

echo ""
echo "========================================"
echo "Running M11-A regression"
echo "========================================"
set +e
BASE_URL="$BASE_URL" ./scripts/validate_m11a.sh
A_RC=$?
set -e
[ "$A_RC" -eq 0 ] && pass "M11-A regression passed" || fail "M11-A regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M11-B VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M11-B VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
