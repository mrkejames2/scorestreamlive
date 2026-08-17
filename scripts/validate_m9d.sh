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
echo "ScoreStreamLive M9-D Real-Time Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}")
    [ "$code" = "200" ] && pass "$path" || fail "$path"
done

TMP=$(mktemp)

set +e
docker compose exec -T -e BASE_URL="$BASE_URL" app python3 - <<'PY' >"$TMP" 2>&1
import concurrent.futures
import json
import os
import sys
import threading
import time
import urllib.error
import urllib.request

import socketio

BASE=os.environ["BASE_URL"]
prefix=f"M9D-{int(time.time())}"
p=f=0

def check(label,cond):
    global p,f
    if cond:
        print(f"[PASS] {label}",flush=True); p+=1
    else:
        print(f"[FAIL] {label}",flush=True); f+=1

def req(method,path,payload=None,allow=False):
    data=None; headers={}
    if payload is not None:
        data=json.dumps(payload).encode()
        headers["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)
    try:
        with urllib.request.urlopen(r,timeout=15) as x:
            raw=x.read()
            return x.status,json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw=e.read()
        body=json.loads(raw) if raw else None
        if allow: return e.code,body
        raise

def team(name,short):
    return req("POST","/api/teams",{"name":name,"short_name":short})[1]

def setup(name):
    a=team(name+"-A","A"); b=team(name+"-B","B")
    g=req("POST","/api/games",{
        "name":name,"home_team_id":a["id"],"away_team_id":b["id"]
    })[1]
    lc=req("POST",f"/api/games/{g['id']}/lifecycle",{})[1]
    cl=req("POST",f"/api/games/{g['id']}/clock",{
        "mode":"count_up","duration_seconds":2700
    })[1]
    return g,lc,cl

def tr(g,action,lv,cv,allow=False):
    return req("POST",f"/api/games/{g['id']}/lifecycle/transition",{
        "action":action,
        "expected_lifecycle_version":lv,
        "expected_clock_version":cv,
    },allow)

class Client:
    def __init__(self,name):
        self.name=name
        self.sio=socketio.Client(reconnection=True)
        self.events=[]
        self.ready=[]
        self.pongs=[]
        self.lock=threading.Lock()

        @self.sio.on("connection:ready")
        def ready(data):
            with self.lock: self.ready.append(data)

        @self.sio.on("server:pong")
        def pong(data):
            with self.lock: self.pongs.append(data)

        @self.sio.on("game:phase_updated")
        def phase(data):
            with self.lock: self.events.append(("phase",time.monotonic(),data))

        @self.sio.on("clock:updated")
        def clock(data):
            with self.lock: self.events.append(("clock",time.monotonic(),data))

    def connect(self):
        self.sio.connect(BASE,socketio_path="/socket.io",transports=["polling"],wait_timeout=15)

    def disconnect(self):
        if self.sio.connected: self.sio.disconnect()

    def clear(self):
        with self.lock: self.events.clear()

    def wait_pair(self,game_id,transition_id,timeout=7):
        deadline=time.time()+timeout
        while time.time()<deadline:
            with self.lock:
                phase=[e for e in self.events if e[0]=="phase"
                       and e[2].get("game_id")==game_id
                       and e[2].get("transition_id")==transition_id]
                clock=[e for e in self.events if e[0]=="clock"
                       and e[2].get("game_id")==game_id
                       and e[2].get("transition_id")==transition_id]
            if phase and clock:
                return phase[-1],clock[-1]
            time.sleep(.05)
        return None,None

    def matching_events(self,game_id):
        with self.lock:
            return [e for e in self.events if e[2].get("game_id")==game_id]

    def events_for_transition(self,game_id,transition_id):
        with self.lock:
            return [e for e in self.events
                    if e[2].get("game_id")==game_id
                    and e[2].get("transition_id")==transition_id]

    def wait_clock_version(self,game_id,clock_version,timeout=7):
        deadline=time.time()+timeout
        while time.time()<deadline:
            with self.lock:
                matches=[e for e in self.events
                         if e[0]=="clock"
                         and e[2].get("game_id")==game_id
                         and e[2].get("version")==clock_version]
            if matches:
                return matches[-1]
            time.sleep(.05)
        return None

    def wait_for_quiet(self,game_id,quiet_seconds=.75,timeout=5):
        deadline=time.time()+timeout
        last=-1
        quiet_since=time.time()
        while time.time()<deadline:
            count=len(self.matching_events(game_id))
            if count!=last:
                last=count
                quiet_since=time.time()
            elif time.time()-quiet_since>=quiet_seconds:
                return count
            time.sleep(.05)
        return len(self.matching_events(game_id))

c1=Client("A"); c2=Client("B")
c1.connect(); c2.connect()
check("Client A connected",c1.sio.connected)
check("Client B connected",c2.sio.connected)

time.sleep(.3)
check("Client A connection:ready",len(c1.ready)>=1)
check("Client B connection:ready",len(c2.ready)>=1)

c1.sio.emit("client:ping",{"source":"m9d"})
deadline=time.time()+3
while time.time()<deadline and not c1.pongs:
    time.sleep(.05)
check("client:ping/server:pong regression",len(c1.pongs)>=1)

g,_,_=setup(prefix+"-MATCH")

steps=[
    ("start_first_half","first_half","running",0,2700),
    ("end_first_half","halftime","paused",None,2700),
    ("start_second_half","second_half","running",2700,5400),
    ("end_game","full_time","paused",None,5400),
]

lv=cv=1
for action,phase,status,base_elapsed,duration in steps:
    c1.clear(); c2.clear()
    http,response=tr(g,action,lv,cv)
    check(f"{action} REST 200",http==200)
    tid=str(response["transition_id"])
    check(f"{action} transition_id present",bool(tid))

    a_phase,a_clock=c1.wait_pair(g["id"],tid)
    b_phase,b_clock=c2.wait_pair(g["id"],tid)

    check(f"{action} Client A receives phase+clock",a_phase is not None and a_clock is not None)
    check(f"{action} Client B receives phase+clock",b_phase is not None and b_clock is not None)

    if a_phase and a_clock:
        check(f"{action} Client A phase before clock",a_phase[1] <= a_clock[1])
        check(f"{action} Client A same transition_id",
              a_phase[2]["transition_id"]==a_clock[2]["transition_id"]==tid)
        check(f"{action} phase event committed version",
              a_phase[2]["version"]==response["lifecycle"]["version"])
        check(f"{action} clock event committed version",
              a_clock[2]["version"]==response["clock"]["version"])
        check(f"{action} phase event value",a_phase[2]["phase"]==phase)
        check(f"{action} clock status value",a_clock[2]["status"]==status)

    if b_phase and b_clock:
        check(f"{action} Client B phase before clock",b_phase[1] <= b_clock[1])
        check(f"{action} clients agree lifecycle version",
              b_phase[2]["version"]==response["lifecycle"]["version"])
        check(f"{action} clients agree clock version",
              b_clock[2]["version"]==response["clock"]["version"])

    check(f"{action} REST phase matches",response["lifecycle"]["phase"]==phase)
    check(f"{action} REST clock status matches",response["clock"]["status"]==status)
    check(f"{action} duration correct",response["clock"]["duration_seconds"]==duration)

    if base_elapsed is not None:
        check(f"{action} elapsed base correct",
              response["clock"]["elapsed_seconds"]==base_elapsed)

    lv=response["lifecycle"]["version"]
    cv=response["clock"]["version"]

# Failed transition suppression.
gf,_,gf_clock=setup(prefix+"-FAIL")

# Drain the expected setup-time clock:updated event before the test window.
setup_clock_a=c1.wait_clock_version(gf["id"],gf_clock["version"])
setup_clock_b=c2.wait_clock_version(gf["id"],gf_clock["version"])
check("stale test setup clock received Client A",setup_clock_a is not None)
check("stale test setup clock received Client B",setup_clock_b is not None)

c1.clear(); c2.clear()

status,_=tr(gf,"start_first_half",1,99,True)
check("stale clock transition returns 409",status==409)
time.sleep(.75)
check("stale transition emits nothing Client A",len(c1.matching_events(gf["id"]))==0)
check("stale transition emits nothing Client B",len(c2.matching_events(gf["id"]))==0)

# Concurrent loser: exactly one correlated winner pair.
gc,_,gc_clock=setup(prefix+"-CON")

# Drain setup-time clock:updated before the concurrency window.
setup_clock_a=c1.wait_clock_version(gc["id"],gc_clock["version"])
setup_clock_b=c2.wait_clock_version(gc["id"],gc_clock["version"])
check("concurrency setup clock received Client A",setup_clock_a is not None)
check("concurrency setup clock received Client B",setup_clock_b is not None)

c1.clear(); c2.clear()

def same():
    return tr(gc,"start_first_half",1,1,True)

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    futures=[pool.submit(same),pool.submit(same)]
    results=[future.result() for future in futures]

statuses=sorted([x[0] for x in results])
check("concurrent integrated one 200 / one 409",statuses==[200,409])

winner=[x[1] for x in results if x[0]==200][0]
winner_tid=str(winner["transition_id"])

a_phase,a_clock=c1.wait_pair(gc["id"],winner_tid)
b_phase,b_clock=c2.wait_pair(gc["id"],winner_tid)

check("concurrent winner Client A receives one pair",a_phase is not None and a_clock is not None)
check("concurrent winner Client B receives one pair",b_phase is not None and b_clock is not None)

c1.wait_for_quiet(gc["id"])
c2.wait_for_quiet(gc["id"])

a_events=c1.matching_events(gc["id"])
b_events=c2.matching_events(gc["id"])

a_transition_ids={e[2].get("transition_id") for e in a_events}
b_transition_ids={e[2].get("transition_id") for e in b_events}

check("concurrent loser emits no extra transition Client A",
      a_transition_ids=={winner_tid})
check("concurrent loser emits no extra transition Client B",
      b_transition_ids=={winner_tid})

a_winner=c1.events_for_transition(gc["id"],winner_tid)
b_winner=c2.events_for_transition(gc["id"],winner_tid)

check("concurrent winner exactly one phase event Client A",
      len([e for e in a_winner if e[0]=="phase"])==1)
check("concurrent winner exactly one clock event Client A",
      len([e for e in a_winner if e[0]=="clock"])==1)
check("concurrent winner exactly one phase event Client B",
      len([e for e in b_winner if e[0]=="phase"])==1)
check("concurrent winner exactly one clock event Client B",
      len([e for e in b_winner if e[0]=="clock"])==1)

# Reconnect + late authoritative recovery.
gr,_,gr_clock=setup(prefix+"-RECONNECT")

# Drain setup event so reconnect starts from a known event boundary.
c1.wait_clock_version(gr["id"],gr_clock["version"])
c2.wait_clock_version(gr["id"],gr_clock["version"])
c1.clear(); c2.clear()

status,r=tr(gr,"start_first_half",1,1)
check("reconnect test starts first half",status==200)
before=r["clock"]["authoritative_elapsed_seconds"]

c2.disconnect()
time.sleep(2)
c2.connect()
time.sleep(.3)

_,lc_now=req("GET",f"/api/games/{gr['id']}/lifecycle")
_,cl_now=req("GET",f"/api/games/{gr['id']}/clock")

check("reconnect lifecycle recovery first_half",lc_now["phase"]=="first_half")
check("reconnect clock recovery running",cl_now["status"]=="running")
check("reconnect clock includes disconnect interval",
      cl_now["authoritative_elapsed_seconds"] > before)

c1.disconnect(); c2.disconnect()

print("========================================")
print(f"M9-D Socket Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY
RC=$?
set -e

cat "$TMP"

P=$(grep -oP 'M9-D Socket Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)

PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))

rm -f "$TMP"

[ "$RC" -eq 0 ] \
    && pass "M9-D Socket.IO process passed" \
    || fail "M9-D Socket.IO process failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
    echo "M9-D VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M9-D VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi