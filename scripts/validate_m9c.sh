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
echo "ScoreStreamLive M9-C Atomic Integration Regression"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}")
    [ "$code" = "200" ] && pass "$path" || fail "$path"
done

TMP=$(mktemp)
set +e
python3 - <<'PY' >"$TMP" 2>&1
import concurrent.futures, json, os, sys, time, urllib.error, urllib.request
base=os.environ["BASE_URL"]
prefix=f"M9C-REG-{int(time.time())}"
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
        data=json.dumps(payload).encode(); headers["Content-Type"]="application/json"
    r=urllib.request.Request(base+path,data=data,headers=headers,method=method)
    try:
        with urllib.request.urlopen(r,timeout=10) as x:
            raw=x.read()
            return x.status,json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw=e.read()
        if allow: return e.code,json.loads(raw) if raw else None
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
        "mode":"count_down","duration_seconds":999
    })[1]
    return g,lc,cl

def tr(g,action,lv,cv,allow=False):
    return req("POST",f"/api/games/{g['id']}/lifecycle/transition",{
        "action":action,
        "expected_lifecycle_version":lv,
        "expected_clock_version":cv,
    },allow)

g,lc,cl=setup(prefix+"-MATCH")
status,s=tr(g,"start_first_half",1,1)
check("start_first_half 200",status==200)
check("first_half + clock running",
      s["lifecycle"]["phase"]=="first_half"
      and s["clock"]["status"]=="running"
      and s["clock"]["elapsed_seconds"]==0
      and s["clock"]["duration_seconds"]==2700)

time.sleep(1)
status,s=tr(g,"end_first_half",2,2)
check("end_first_half 200",status==200)
check("halftime + paused",
      s["lifecycle"]["phase"]=="halftime"
      and s["clock"]["status"]=="paused"
      and s["clock"]["running_since"] is None)

status,s=tr(g,"start_second_half",3,3)
check("start_second_half 200",status==200)
check("second_half begins 45:00",
      s["lifecycle"]["phase"]=="second_half"
      and s["clock"]["status"]=="running"
      and s["clock"]["elapsed_seconds"]==2700
      and s["clock"]["duration_seconds"]==5400)

status,s=tr(g,"end_game",4,4)
check("end_game 200",status==200)
check("full_time + paused",
      s["lifecycle"]["phase"]=="full_time"
      and s["clock"]["status"]=="paused")

# stale clock => neither changes
g2,_,_=setup(prefix+"-STALE")
_,lb=req("GET",f"/api/games/{g2['id']}/lifecycle")
_,cb=req("GET",f"/api/games/{g2['id']}/clock")
status,_=tr(g2,"start_first_half",1,99,True)
check("stale clock rejected 409",status==409)
_,la=req("GET",f"/api/games/{g2['id']}/lifecycle")
_,ca=req("GET",f"/api/games/{g2['id']}/clock")
check("stale clock leaves lifecycle unchanged",
      lb["phase"]==la["phase"] and lb["version"]==la["version"])
check("stale clock leaves clock unchanged",
      all(cb[k]==ca[k] for k in (
          "version","status","mode","duration_seconds","elapsed_seconds","running_since"
      )))

# same-version concurrent integrated transition
g3,_,_=setup(prefix+"-CON")
def go():
    return tr(g3,"start_first_half",1,1,True)[0]

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    statuses=sorted([x.result() for x in [pool.submit(go),pool.submit(go)]])
check("concurrent integrated one 200 / one 409",statuses==[200,409])

_,lf=req("GET",f"/api/games/{g3['id']}/lifecycle")
_,cf=req("GET",f"/api/games/{g3['id']}/clock")
check("concurrent lifecycle increments once",
      lf["phase"]=="first_half" and lf["version"]==2)
check("concurrent clock increments once",
      cf["status"]=="running" and cf["version"]==2)

print(f"M9-C Regression Tests Passed: {p} Failed: {f}")
sys.exit(1 if f else 0)
PY
RC=$?
set -e

cat "$TMP"
P=$(grep -oP 'M9-C Regression Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] && pass "M9-C atomic regression process passed" || fail "M9-C atomic regression process failed"

echo "========================================"
if [ "$FAIL" -eq 0 ]; then
    echo "M9-C ATOMIC REGRESSION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    exit 0
else
    echo "M9-C ATOMIC REGRESSION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    exit 1
fi
