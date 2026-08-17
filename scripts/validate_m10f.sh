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
echo "ScoreStreamLive M10-F Connection + Conflict Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path"
done

for item in \
  "/static/js/control/control.js|control.js" \
  "/static/js/control/socket.js|socket.js" \
  "/static/js/control/state.js|state.js" \
  "/static/css/control.css|control.css"
do
  path="${item%%|*}"
  label="${item#*|}"
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$label preflight" || fail "$label preflight HTTP ${code}"
done

TMP=$(mktemp)
set +e
docker compose exec -T -e BASE_URL="$BASE_URL" app python3 - <<'PY' >"$TMP" 2>&1
import concurrent.futures
import json
import os
import sys
import time
import urllib.error
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

def req(method,path,payload=None,allow=False):
    data=None; headers={}
    if payload is not None:
        data=json.dumps(payload).encode()
        headers["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)
    try:
        with urllib.request.urlopen(r,timeout=15) as x:
            raw=x.read()
            ct=x.headers.get("Content-Type","")
            body=json.loads(raw) if raw and "application/json" in ct.lower() else raw.decode(errors="replace")
            return x.status,body,ct
    except urllib.error.HTTPError as e:
        raw=e.read()
        try:
            body=json.loads(raw) if raw else None
        except Exception:
            body=raw.decode(errors="replace")
        if allow:
            return e.code,body,e.headers.get("Content-Type","")
        raise

def team(name,short):
    return req("POST","/api/teams",{"name":name,"short_name":short})[1]

home=team(f"M10F-H-{stamp}","H")
away=team(f"M10F-A-{stamp}","A")
game=req("POST","/api/games",{
    "name":f"M10F-G-{stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]
req("POST",f"/api/games/{game['id']}/lifecycle",{})
req("POST",f"/api/games/{game['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})

_,page,ct=req("GET",f"/control/games/{game['id']}")
check("Control Center returns HTML","text/html" in ct.lower())
check(
    "Control Center preserves M10-F connection/conflict capability",
    "connection-badge" in page
    and "socket-message-text" in page
    and "match-status-strip" in page
    and "home-goal-button" in page
    and "away-goal-button" in page,
)
check("Controls-paused recovery message present","socket-message-text" in page)
check("M10-E match-day status strip preserved","match-status-strip" in page)
check("M10-D scoring controls preserved","home-goal-button" in page and "away-goal-button" in page)

_,state_js,_=req("GET","/static/js/control/state.js")
check("State tracks connectionState","connectionState" in state_js)
check("State tracks stateAuthoritative","stateAuthoritative" in state_js)

_,socket_js,_=req("GET","/static/js/control/socket.js")
check("Socket enters recovering state",'setConnectionState("recovering")' in socket_js)
check(
    "Socket does not mark mutation-ready before recovery",
    socket_js.find("setSocketConnected(true)")
    > socket_js.find("await onAuthoritativeRefresh"),
)
check("Socket recovery is callable","recoverAuthoritativeState" in socket_js)
check(
    "Reconnect attempts invalidate authoritative state",
    "reconnect_attempt" in socket_js
    and "setStateAuthoritative(false)" in socket_js,
)

_,control_js,_=req("GET","/static/js/control/control.js")
check(
    "Mutation readiness requires authoritative state",
    "state.stateAuthoritative" in control_js
    and "mutationStateIsReady" in control_js,
)
check(
    "Lifecycle controls use readiness gate",
    "!ready" in control_js
    and "renderLifecycleControls" in control_js,
)
check(
    "Scoring controls use readiness gate",
    "goalEnabled" in control_js
    and "mutationStateIsReady()" in control_js,
)
check(
    "409 conflict explicitly not retried",
    "Your command was not retried" in control_js,
)
check(
    "409 conflict invalidates local authority before refresh",
    "setStateAuthoritative(false)" in control_js,
)
check(
    "Recovery failure keeps controls paused",
    "Controls remain paused" in control_js,
)
check(
    "No automatic conflict retry loop",
    "while (error?.status === 409)" not in control_js,
)
check(
    "No clock:tick consumer introduced",
    'socket.on("clock:tick"' not in control_js
    and "socket.on('clock:tick'" not in control_js,
)

payload={
    "action":"start_first_half",
    "expected_lifecycle_version":1,
    "expected_clock_version":1,
}

def transition():
    return req(
        "POST",
        f"/api/games/{game['id']}/lifecycle/transition",
        payload,
        True,
    )

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    results=[
        future.result()
        for future in [
            pool.submit(transition),
            pool.submit(transition),
        ]
    ]

statuses=sorted(result[0] for result in results)
check(
    "Two controllers produce one committed action / one conflict",
    statuses==[200,409],
)

_,lc,_=req("GET",f"/api/games/{game['id']}/lifecycle")
_,cl,_=req("GET",f"/api/games/{game['id']}/clock")
check(
    "Conflict leaves authoritative lifecycle consistent",
    lc["phase"]=="first_half"
    and lc["version"]==2,
)
check(
    "Conflict leaves authoritative clock consistent",
    cl["status"]=="running"
    and cl["version"]==2,
)

print("========================================")
print(f"M10-F Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY
RC=$?
set -e

cat "$TMP"
P=$(grep -oP 'M10-F Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M10-F reliability process passed" \
  || fail "M10-F reliability process failed"

echo ""
echo "========================================"
echo "Running M10-E regression"
echo "========================================"
set +e
BASE_URL="$BASE_URL" ./scripts/validate_m10e.sh
M10E_RC=$?
set -e

[ "$M10E_RC" -eq 0 ] \
  && pass "M10-E regression passed" \
  || fail "M10-E regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M10-F VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M10-F VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
