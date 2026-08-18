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
echo "ScoreStreamLive M10-G Mobile + Tablet UX Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path"
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
    r=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)
    with urllib.request.urlopen(r,timeout=15) as x:
        raw=x.read()
        ct=x.headers.get("Content-Type","")
        body=json.loads(raw) if raw and "application/json" in ct.lower() else raw.decode(errors="replace")
        return x.status,body,ct

h=req("POST","/api/teams",{"name":f"M10G-H-{stamp}","short_name":"H"})[1]
a=req("POST","/api/teams",{"name":f"M10G-A-{stamp}","short_name":"A"})[1]
g=req("POST","/api/games",{
    "name":f"M10G-G-{stamp}",
    "home_team_id":h["id"],
    "away_team_id":a["id"],
})[1]
req("POST",f"/api/games/{g['id']}/lifecycle",{})
req("POST",f"/api/games/{g['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})

_,page,ct=req("GET",f"/control/games/{g['id']}")
check("Control Center returns HTML","text/html" in ct.lower())
check(
    "M10-G mobile/tablet Control Center capability preserved",
    "match-status-strip" in page
    and "lifecycle-actions" in page
    and "home-goal-button" in page
    and "away-goal-button" in page
    and "home-roster" in page
    and "away-roster" in page,
)
check("M10-F connection badge preserved","connection-badge" in page)
check("M10-E status strip preserved","match-status-strip" in page)
check("Lifecycle controls preserved","lifecycle-actions" in page)
check("Scoring controls preserved","home-goal-button" in page and "away-goal-button" in page)
check("Scoring summary preserved","scoring-list" in page)
check("Rosters preserved","home-roster" in page and "away-roster" in page)

_,css,_=req("GET","/static/css/control.css")
check("Phone breakpoint preserved","@media (max-width: 520px)" in css)
check("Small-phone breakpoint exists","@media (max-width: 360px)" in css)
check("Phone scoreboard is compact three-column layout",
      "grid-template-columns: minmax(0, .95fr) minmax(126px, 1.2fr) minmax(0, .95fr)" in css)
check("Phone status strip stays one row","grid-template-columns: repeat(3, minmax(0, 1fr))" in css)
check("Phone lifecycle hides irrelevant actions",
      ".lifecycle-button:not(.current-action)" in css)
check("Phone goal controls support side-by-side layout",
      ".scoring-control-grid" in css and "grid-template-columns: 1fr 1fr" in css)
check("Goal buttons retain large touch target","min-height: 64px" in css)
check("iOS form zoom guard present","font-size: 16px" in css)
check("Phone footer removed from game-day view",".control-footer" in css and "display: none" in css)

_,js,_=req("GET","/static/js/control/control.js")
check("Current lifecycle action presentation marker exists","current-action" in js)
check("M10-F mutation readiness preserved","mutationStateIsReady" in js)
check("M10-F authoritative guard preserved","state.stateAuthoritative" in js)
check("No client-side score arithmetic","home_score + 1" not in js and "away_score + 1" not in js)
check("No clock:tick consumer","socket.on(\"clock:tick\"" not in js and "socket.on('clock:tick'" not in js)

print("========================================")
print(f"M10-G Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY
RC=$?
set -e

cat "$TMP"
P=$(grep -oP 'M10-G Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M10-G mobile/tablet UX process passed" \
  || fail "M10-G mobile/tablet UX process failed"

echo ""
echo "========================================"
echo "Running M10-F regression"
echo "========================================"
set +e
BASE_URL="$BASE_URL" ./scripts/validate_m10f.sh
M10F_RC=$?
set -e

[ "$M10F_RC" -eq 0 ] \
  && pass "M10-F regression passed" \
  || fail "M10-F regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M10-G VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M10-G VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
