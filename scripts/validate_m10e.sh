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
echo "ScoreStreamLive M10-E Match-Day UX Validation"
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
p=f=0
def check(label,cond):
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
stamp=int(time.time())
h=req("POST","/api/teams",{"name":f"M10E-H-{stamp}","short_name":"H"})[1]
a=req("POST","/api/teams",{"name":f"M10E-A-{stamp}","short_name":"A"})[1]
g=req("POST","/api/games",{"name":f"M10E-G-{stamp}","home_team_id":h["id"],"away_team_id":a["id"]})[1]
req("POST",f"/api/games/{g['id']}/lifecycle",{})
req("POST",f"/api/games/{g['id']}/clock",{"mode":"count_up","duration_seconds":2700})
_,page,ct=req("GET",f"/control/games/{g['id']}")
check("Control Center returns HTML","text/html" in ct.lower())
check("Control Center identifies M10-E","M10-E" in page)
check("Match-day status strip present","match-status-strip" in page)
check("Goal feedback surface present","goal-feedback" in page)
check("Lifecycle controls preserved",all(x in page for x in ["start_first_half","end_first_half","start_second_half","end_game"]))
check("Scoring controls preserved","home-goal-button" in page and "away-goal-button" in page)
_,css,_=req("GET","/static/css/control.css")
check("Touch-first goal sizing present","min-height: 70px" in css)
check("Responsive mobile breakpoint present","@media (max-width: 520px)" in css)
check("Sticky scoreboard present","position: sticky" in css)
_,js,_=req("GET","/static/js/control/control.js")
check("M10-E UX synchronization exists","syncMatchDayUx" in js)
check("Goal feedback behavior exists","showGoalFeedback" in js)
check("Lifecycle guard preserved","commandInFlight" in js)
check("Scoring guard preserved","scoringInFlight" in js)
check("Authoritative refresh preserved","fetchAuthoritativeState" in js)
check("No client-side score arithmetic","home_score + 1" not in js and "away_score + 1" not in js)
check("No clock:tick consumer","socket.on(\"clock:tick\"" not in js and "socket.on('clock:tick'" not in js)
print("========================================")
print(f"M10-E Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY
RC=$?
set -e
cat "$TMP"
P=$(grep -oP 'M10-E Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"
[ "$RC" -eq 0 ] && pass "M10-E UX process passed" || fail "M10-E UX process failed"

echo ""
echo "========================================"
echo "Running M10-D regression"
echo "========================================"
set +e
BASE_URL="$BASE_URL" ./scripts/validate_m10d.sh
M10D_RC=$?
set -e
[ "$M10D_RC" -eq 0 ] && pass "M10-D regression passed" || fail "M10-D regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M10-E VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M10-E VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
