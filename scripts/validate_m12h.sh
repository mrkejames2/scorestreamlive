#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://192.168.1.196:8000}"
BASE_URL="${BASE_URL%/}"
VALIDATION_MODE="${VALIDATION_MODE:-local}"

case "$VALIDATION_MODE" in
  local|production) ;;
  *) echo "ERROR: VALIDATION_MODE must be local or production" >&2; exit 2 ;;
esac

export BASE_URL VALIDATION_MODE

PASS=0
FAIL=0
FAILURES=()
pass(){ PASS=$((PASS+1)); }
fail(){ FAIL=$((FAIL+1)); FAILURES+=("$1"); }
progress(){ echo "[$1/12] $2"; }

check_http() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass || fail "${path} HTTP ${code}"
}

FLOW_TMP=$(mktemp)
REG_TMP=$(mktemp)
trap 'rm -f "$FLOW_TMP" "$REG_TMP"' EXIT

progress 1 "Checking application health and Milestone 12 entry surfaces..."
check_http /health/live
check_http /health/ready
check_http /info
check_http /games

progress 2 "Creating fresh branded Home and Away Teams..."
progress 3 "Creating a fresh Game and initializing lifecycle/clock..."
progress 4 "Creating Home and Away roster Players..."
progress 5 "Verifying Game Management, Game Hub, roster, Control Center, and Overlay routes..."
progress 6 "Starting First Half and verifying authoritative running state..."
progress 7 "Recording Home and Away goals..."
progress 8 "Transitioning through Halftime and Second Half..."
progress 9 "Ending the Game at Full Time..."
progress 10 "Verifying final score, lifecycle, rosters, and scoring history..."

set +e
python3 - <<'PY' >"$FLOW_TMP" 2>&1
import json, os, sys, time, urllib.request
BASE=os.environ["BASE_URL"]
stamp=int(time.time())
p=f=0
fails=[]

def check(label, cond):
    global p,f
    if cond: p+=1
    else: f+=1; fails.append(label)

def req(method,path,payload=None):
    data=None
    headers={"Accept":"application/json"}
    if payload is not None:
        data=json.dumps(payload).encode()
        headers["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)
    with urllib.request.urlopen(r,timeout=20) as x:
        raw=x.read(); ct=x.headers.get("Content-Type","")
        body=json.loads(raw) if raw and "application/json" in ct.lower() else raw.decode(errors="replace")
        return x.status,body,ct

def get(path): return req("GET",path)[1]

home=req("POST","/api/teams",{
    "name":f"M12-H Home {stamp}",
    "short_name":"HHOME",
    "primary_color":"#C8102E",
    "secondary_color":"#FFD100",
})[1]
away=req("POST","/api/teams",{
    "name":f"M12-H Away {stamp}",
    "short_name":"HAWAY",
    "primary_color":"#0057B8",
    "secondary_color":"#FFFFFF",
})[1]
check("Fresh Home Team created",bool(home.get("id")))
check("Fresh Away Team created",bool(away.get("id")))

game=req("POST","/api/games",{
    "name":f"M12-H Final Acceptance {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]
check("Fresh Game created",bool(game.get("id")))

lifecycle=req("POST",f"/api/games/{game['id']}/lifecycle",{})[1]
clock=req("POST",f"/api/games/{game['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})[1]
check("Lifecycle initialized to pregame",lifecycle.get("phase")=="pregame")
check("Clock initialized",clock.get("mode")=="count_up")

hp=req("POST","/api/players",{
    "team_id":home["id"],"first_name":"Alex","last_name":"Final","jersey_number":9
})[1]
ap=req("POST","/api/players",{
    "team_id":away["id"],"first_name":"Jordan","last_name":"Final","jersey_number":14
})[1]
check("Home Player created",bool(hp.get("id")))
check("Away Player created",bool(ap.get("id")))

for path,label in [
    ("/games","Game Management route"),
    (f"/games/{game['id']}","Game Hub route"),
    (f"/games/{game['id']}/setup","Roster Management route"),
    (f"/control/games/{game['id']}","Control Center route"),
    (f"/overlay/games/{game['id']}","Broadcast Overlay route"),
]:
    status,_,ct=req("GET",path)
    check(label,status==200 and "text/html" in ct.lower())

t=req("POST",f"/api/games/{game['id']}/lifecycle/transition",{
    "action":"start_first_half",
    "expected_lifecycle_version":lifecycle["version"],
    "expected_clock_version":clock["version"],
})[1]
lifecycle=t["lifecycle"]; clock=t["clock"]
check("First Half transition succeeds",lifecycle.get("phase")=="first_half")
check("Clock runs in First Half",clock.get("status")=="running")
time.sleep(1)

hg=req("POST","/api/scoring-events",{
    "game_id":game["id"],"team_id":home["id"],"player_id":hp["id"],"event_type":"goal"
})[1]
ag=req("POST","/api/scoring-events",{
    "game_id":game["id"],"team_id":away["id"],"player_id":ap["id"],"event_type":"goal"
})[1]
check("Home goal recorded",hg.get("event_type")=="goal")
check("Away goal recorded",ag.get("event_type")=="goal")

fresh=get(f"/api/games/{game['id']}")
check("Score becomes 1-1",fresh.get("home_score")==1 and fresh.get("away_score")==1)

for action,phase in [
    ("end_first_half","halftime"),
    ("start_second_half","second_half"),
    ("end_game","full_time"),
]:
    t=req("POST",f"/api/games/{game['id']}/lifecycle/transition",{
        "action":action,
        "expected_lifecycle_version":lifecycle["version"],
        "expected_clock_version":clock["version"],
    })[1]
    lifecycle=t["lifecycle"]; clock=t["clock"]
    check(f"{phase} transition succeeds",lifecycle.get("phase")==phase)

check("Clock is not running at Full Time",clock.get("status")!="running")

fg=get(f"/api/games/{game['id']}")
fl=get(f"/api/games/{game['id']}/lifecycle")
fc=get(f"/api/games/{game['id']}/clock")
hr=get(f"/api/teams/{home['id']}/players")
ar=get(f"/api/teams/{away['id']}/players")
se=get(f"/api/games/{game['id']}/scoring-events")
games=get("/api/games")

check("Final authoritative score remains 1-1",fg.get("home_score")==1 and fg.get("away_score")==1)
check("Final lifecycle remains Full Time",fl.get("phase")=="full_time")
check("Final clock remains recoverable",isinstance(fc,dict) and fc.get("game_id")==game["id"])
check("Home roster persists",any(str(x.get("id"))==str(hp["id"]) for x in hr))
check("Away roster persists",any(str(x.get("id"))==str(ap["id"]) for x in ar))
check("Both scoring events persist",len([x for x in se if x.get("event_type")=="goal"])>=2)
check("Completed Game remains rediscoverable from Game collection",
      any(str(x.get("id"))==str(game["id"]) for x in games))

for path,label in [
    (f"/games/{game['id']}","Completed Game Hub reopens"),
    (f"/control/games/{game['id']}","Completed Control Center reopens"),
    (f"/overlay/games/{game['id']}","Completed Broadcast Overlay reopens"),
]:
    status,_,ct=req("GET",path)
    check(label,status==200 and "text/html" in ct.lower())

for label in fails: print("[FAIL] "+label)
print(f"M12H_PASS={p}")
print(f"M12H_FAIL={f}")
sys.exit(1 if f else 0)
PY
FLOW_RC=$?
set -e

FP=$(grep -oP 'M12H_PASS=\K[0-9]+' "$FLOW_TMP" | tail -1 || true)
FF=$(grep -oP 'M12H_FAIL=\K[0-9]+' "$FLOW_TMP" | tail -1 || true)
PASS=$((PASS + ${FP:-0}))
FAIL=$((FAIL + ${FF:-0}))

while IFS= read -r line; do
  [ -n "$line" ] && FAILURES+=("${line#\[FAIL\] }")
done < <(grep '^\[FAIL\]' "$FLOW_TMP" || true)

if [ "$FLOW_RC" -ne 0 ] && [ "${FF:-0}" -eq 0 ]; then
  fail "M12-H end-to-end acceptance flow failed unexpectedly"
fi

if [ "$VALIDATION_MODE" = "local" ]; then
  progress 11 "Running M12-G cumulative recovery regression silently..."
  set +e
  BASE_URL="$BASE_URL" ./scripts/validate_m12g.sh >"$REG_TMP" 2>&1
  REG_RC=$?
  set -e
  if [ "$REG_RC" -ne 0 ]; then
    FAILURES+=("M12-G cumulative regression failed")
    while IFS= read -r line; do
      [ -n "$line" ] && FAILURES+=("$line")
    done < <(grep -E '^\[FAIL\]|VALIDATION FAILED|OVERALL[[:space:]]+.*FAIL' "$REG_TMP" | tail -40 || true)
  fi
else
  progress 11 "Skipping local-only Docker recovery regression in production mode..."
  REG_RC=0
fi

progress 12 "Building Milestone 12 release summary..."
echo "========================================"
echo "ScoreStreamLive M12-H Final Release Summary"
echo "BASE_URL: ${BASE_URL}"
echo "MODE: ${VALIDATION_MODE}"
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo "M12-H end-to-end ..... PASS   ${PASS} passed / 0 failed"
else
  echo "M12-H end-to-end ..... FAIL   ${PASS} passed / ${FAIL} failed"
fi

if [ "$VALIDATION_MODE" = "local" ]; then
  [ "$REG_RC" -eq 0 ]     && echo "M12-G cumulative .... PASS"     || echo "M12-G cumulative .... FAIL"
else
  echo "M12-G cumulative .... SKIPPED (local-only)"
fi

echo "========================================"

TOTAL_FAIL=$FAIL
if [ "$VALIDATION_MODE" = "local" ] && [ "$REG_RC" -ne 0 ]; then
  TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo "OVERALL ............. PASS"
  echo "Failed Components: None"
  echo "========================================"
  echo "M12-H AUTOMATED ACCEPTANCE = PASS"
  [ "$VALIDATION_MODE" = "production" ]     && echo "MILESTONE 12 PRODUCTION RELEASE GATE = PASS"     || echo "MILESTONE 12 LOCAL RELEASE GATE = PASS"
  exit 0
fi

echo "OVERALL ............. FAIL"
echo ""
echo "FAILED COMPONENTS"
echo "-----------------"
printf '%s\n' "${FAILURES[@]}" | awk 'NF && !seen[$0]++ {print "- "$0}'
echo "========================================"
echo "M12-H AUTOMATED ACCEPTANCE = FAIL"
[ "$VALIDATION_MODE" = "production" ]   && echo "MILESTONE 12 PRODUCTION RELEASE GATE = FAIL"   || echo "MILESTONE 12 LOCAL RELEASE GATE = FAIL"
exit 1
