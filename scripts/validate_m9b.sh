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
echo "ScoreStreamLive M9-B Lifecycle Regression"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}")
    [ "$code" = "200" ] && pass "$path" || fail "$path"
done

TMP=$(mktemp)
set +e
python3 - <<'PY' >"$TMP" 2>&1
import json, os, sys, time, urllib.request, urllib.error
base=os.environ["BASE_URL"]
prefix=f"M9B-REG-{int(time.time())}"
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
    r=urllib.request.Request(base+path,data=data,headers=headers,method=method)
    try:
        with urllib.request.urlopen(r,timeout=10) as x:
            raw=x.read()
            return x.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw=e.read()
        if allow:
            return e.code, json.loads(raw) if raw else None
        raise

def team(name, short):
    return req("POST","/api/teams",{"name":name,"short_name":short})[1]

a=team(prefix+"-A","A"); b=team(prefix+"-B","B")
g=req("POST","/api/games",{
    "name":prefix+"-GAME",
    "home_team_id":a["id"],
    "away_team_id":b["id"],
})[1]

status,lc=req("POST",f"/api/games/{g['id']}/lifecycle",{})
check("Lifecycle creation 201", status==201)
check("Lifecycle starts pregame", lc["phase"]=="pregame")
check("Lifecycle starts version 1", lc["version"]==1)

status,got=req("GET",f"/api/games/{g['id']}/lifecycle")
check("Lifecycle GET 200", status==200 and got["phase"]=="pregame")

clock=req("POST",f"/api/games/{g['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})[1]

lv=1; cv=clock["version"]
chain=[
    ("start_first_half","first_half"),
    ("end_first_half","halftime"),
    ("start_second_half","second_half"),
    ("end_game","full_time"),
]

for action,phase in chain:
    status,state=req(
        "POST",
        f"/api/games/{g['id']}/lifecycle/transition",
        {
            "action":action,
            "expected_lifecycle_version":lv,
            "expected_clock_version":cv,
        },
    )
    check(f"{action} returns 200", status==200)
    check(f"{action} lifecycle phase {phase}",
          state["lifecycle"]["phase"]==phase)
    check(f"{action} lifecycle version increments",
          state["lifecycle"]["version"]==lv+1)
    lv=state["lifecycle"]["version"]
    cv=state["clock"]["version"]

status,_=req(
    "POST",
    f"/api/games/{g['id']}/lifecycle/transition",
    {
        "action":"end_game",
        "expected_lifecycle_version":lv,
        "expected_clock_version":cv,
    },
    True,
)
check("full_time remains terminal", status==409)

print("========================================")
print(f"M9-B Regression Tests Passed: {p} Failed: {f}")
sys.exit(1 if f else 0)
PY
RC=$?
set -e

cat "$TMP"
P=$(grep -oP 'M9-B Regression Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] && pass "M9-B lifecycle regression process passed" || fail "M9-B lifecycle regression process failed"

echo "========================================"
if [ "$FAIL" -eq 0 ]; then
    echo "M9-B LIFECYCLE REGRESSION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    exit 0
else
    echo "M9-B LIFECYCLE REGRESSION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    exit 1
fi
