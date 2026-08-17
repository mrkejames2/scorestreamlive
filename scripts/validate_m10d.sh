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
echo "ScoreStreamLive M10-D Scoring Control Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path"
done

for asset in /static/js/control/api.js /static/js/control/control.js /static/css/control.css; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${asset}" || true)
  [ "$code" = "200" ] && pass "${asset} preflight" || fail "${asset} preflight returned ${code}"
done

TMP=$(mktemp)
set +e
docker compose exec -T -e BASE_URL="$BASE_URL" app python3 - <<'PY' >"$TMP" 2>&1
import json, os, sys, time, urllib.error, urllib.request
import socketio

BASE=os.environ["BASE_URL"]
p=f=0
prefix=f"M10D-{int(time.time())}"

def check(label, cond):
    global p,f
    if cond: print(f"[PASS] {label}", flush=True); p+=1
    else: print(f"[FAIL] {label}", flush=True); f+=1

def req(method,path,payload=None,allow=False):
    data=None; headers={}
    if payload is not None:
        data=json.dumps(payload).encode(); headers["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)
    try:
        with urllib.request.urlopen(r,timeout=15) as x:
            raw=x.read(); ct=x.headers.get("content-type","")
            body=json.loads(raw) if raw and "json" in ct else raw.decode(errors="replace")
            return x.status,body
    except urllib.error.HTTPError as e:
        raw=e.read()
        try: body=json.loads(raw) if raw else None
        except Exception: body=raw.decode(errors="replace")
        if allow: return e.code,body
        raise

def post(path,payload): return req("POST",path,payload)[1]

a=post("/api/teams",{"name":prefix+" HOME","short_name":"HOM"})
b=post("/api/teams",{"name":prefix+" AWAY","short_name":"AWY"})
g=post("/api/games",{"name":prefix+" GAME","home_team_id":a["id"],"away_team_id":b["id"]})
post(f"/api/games/{g['id']}/lifecycle",{})
post(f"/api/games/{g['id']}/clock",{"mode":"count_up","duration_seconds":2700})
hp=post("/api/players",{"team_id":a["id"],"first_name":"Home","last_name":"Scorer","jersey_number":9})
ap=post("/api/players",{"team_id":b["id"],"first_name":"Away","last_name":"Scorer","jersey_number":10})

status,html=req("GET",f"/control/games/{g['id']}")
check("Control Center page returns 200",status==200)
check("Control Center identifies M10-D", "M10-D · LIFECYCLE + SCORING CONTROL" in html)
check("Home goal button present", 'id="home-goal-button"' in html)
check("Away goal button present", 'id="away-goal-button"' in html)
check("Home scorer selector present", 'id="home-scorer-select"' in html)
check("Away scorer selector present", 'id="away-scorer-select"' in html)

_,api=req("GET","/static/js/control/api.js")
_,control=req("GET","/static/js/control/control.js")
check("M10-D uses existing scoring REST endpoint", "/api/scoring-events" in api)
check("M10-D scoring payload uses event_type goal", 'event_type: "goal"' in api)
check("M10-D supports nullable scorer", "player_id: playerId || null" in api)
check("M10-D has scoring in-flight guard", "scoringCommandInFlight" in control)
check("M10-D restricts UI scoring to active halves", '"first_half", "second_half"' in control)
check("M10-D does not implement score arithmetic", "home_score +" not in control and "away_score +" not in control)
check("M10-D does not consume clock:tick", 'socket.on("clock:tick"' not in control)

received=[]
sio=socketio.Client(reconnection=True)
@sio.on("scoring_event:created")
def scoring_event(data): received.append(("event",data))
@sio.on("game:score_updated")
def score_update(data): received.append(("score",data))
sio.connect(BASE,socketio_path="/socket.io",transports=["polling"],wait_timeout=15)

# Put game into an active half through the existing integrated M9 endpoint.
status,tr=req("POST",f"/api/games/{g['id']}/lifecycle/transition",{
    "action":"start_first_half","expected_lifecycle_version":1,"expected_clock_version":1
})
check("Scoring test starts first half",status==200 and tr["lifecycle"]["phase"]=="first_half")

def wait_for(kind, game_id, timeout=5):
    end=time.time()+timeout
    while time.time()<end:
        for k,d in received:
            if k==kind and str(d.get("game_id"))==str(game_id): return d
        time.sleep(.05)
    return None

received.clear()
status,event=req("POST","/api/scoring-events",{
    "game_id":g["id"],"team_id":a["id"],"player_id":hp["id"],"event_type":"goal"
})
check("Home player goal returns 201",status==201)
e=wait_for("event",g["id"]); s=wait_for("score",g["id"])
check("Home goal emits scoring_event:created",e is not None)
check("Home goal emits game:score_updated",s is not None)
check("Home goal event identifies selected scorer",e is not None and e.get("player_id")==hp["id"])
check("Home goal committed score is 1-0",s is not None and s.get("home_score")==1 and s.get("away_score")==0)

received.clear()
status,event=req("POST","/api/scoring-events",{
    "game_id":g["id"],"team_id":b["id"],"player_id":None,"event_type":"goal"
})
check("Away team goal returns 201",status==201)
e=wait_for("event",g["id"]); s=wait_for("score",g["id"])
check("Team goal permits null scorer",e is not None and e.get("player_id") is None)
check("Away goal committed score is 1-1",s is not None and s.get("home_score")==1 and s.get("away_score")==1)

_,game_now=req("GET",f"/api/games/{g['id']}")
_,history=req("GET",f"/api/games/{g['id']}/scoring-events")
check("PostgreSQL-authoritative Game score is 1-1",game_now["home_score"]==1 and game_now["away_score"]==1)
check("Scoring history persisted both goals",len(history)==2)

# Existing backend validation remains authoritative: wrong-team player is rejected.
status,_=req("POST","/api/scoring-events",{
    "game_id":g["id"],"team_id":a["id"],"player_id":ap["id"],"event_type":"goal"
},True)
check("Wrong-team scorer rejected",status==422)
_,game_after=req("GET",f"/api/games/{g['id']}")
check("Rejected goal does not change score",game_after["home_score"]==1 and game_after["away_score"]==1)

sio.disconnect()
print("========================================")
print(f"M10-D Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY
RC=$?
set -e
cat "$TMP"
P=$(grep -oP 'M10-D Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0})); FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"
[ "$RC" -eq 0 ] && pass "M10-D scoring-control process passed" || fail "M10-D scoring-control process failed"

echo ""
echo "========================================"
echo "Running M10-C regression"
echo "========================================"
set +e
BASE_URL="$BASE_URL" ./scripts/validate_m10c.sh
M10C_RC=$?
set -e
[ "$M10C_RC" -eq 0 ] && pass "M10-C regression passed" || fail "M10-C regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M10-D VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M10-D VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
