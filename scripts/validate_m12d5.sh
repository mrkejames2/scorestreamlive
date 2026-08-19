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
echo "ScoreStreamLive M12-D5 Branded Control Center"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /health/live \
  /health/ready \
  /info \
  /static/css/control.css \
  /static/css/control-d5.css \
  /static/js/control/control.js \
  /static/js/control/control-branding.js
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

JS=$(curl -fsS "${BASE_URL}/static/js/control/control-branding.js")
CSS=$(curl -fsS "${BASE_URL}/static/css/control-d5.css")

echo ""
echo "========================================"
echo "M12-D5 Static Capability Checks"
echo "========================================"

grep -Fq 'getJson(`/api/games/${gameId}`)' <<<"$JS" \
  && pass "Branding module reads authoritative Game" \
  || fail "Branding module Game read missing"

grep -Fq 'getJson(`/api/teams/${game.home_team_id}`)' <<<"$JS" \
  && grep -Fq 'getJson(`/api/teams/${game.away_team_id}`)' <<<"$JS" \
  && pass "Branding module reads both Team domains" \
  || fail "Branding module Team reads missing"

grep -Fq 'team?.logo_url' <<<"$JS" \
  && pass "Control branding consumes persisted logo_url" \
  || fail "Control branding logo_url consumer missing"

grep -Fq 'team?.primary_color' <<<"$JS" \
  && grep -Fq 'team?.secondary_color' <<<"$JS" \
  && pass "Control branding consumes Team colors" \
  || fail "Control branding color consumers missing"

grep -Fq 'function teamInitials' <<<"$JS" \
  && grep -Fq 'logo.onerror' <<<"$JS" \
  && pass "Missing/broken logo has initials fallback" \
  || fail "Logo fallback behavior missing"

grep -Fq 'presentation-only' <<<"$JS" \
  && grep -Fq 'brandingState = "fallback"' <<<"$JS" \
  && pass "Branding failure does not block Control Center" \
  || fail "Non-blocking branding failure contract missing"

if grep -Eq 'method:[[:space:]]*"(POST|PATCH|PUT|DELETE)"|method:[[:space:]]*'\''(POST|PATCH|PUT|DELETE)'\''' <<<"$JS"; then
  fail "Branding module introduced mutation request"
else
  pass "Branding module remains read-only"
fi

if grep -Fq 'clock:tick' <<<"$JS"; then
  fail "Branding module consumes clock:tick"
else
  pass "Branding module consumes no clock:tick"
fi

grep -Fq '.branded-control-scoreboard' <<<"$CSS" \
  && grep -Fq '.control-team-logo-shell' <<<"$CSS" \
  && grep -Fq '.branded-scoring-card' <<<"$CSS" \
  && pass "Branded scoreboard/scoring CSS exists" \
  || fail "Control branding CSS missing"

TMP=$(mktemp)
set +e

docker compose exec -T -e BASE_URL="$BASE_URL" app python3 - <<'PY' >"$TMP" 2>&1
import json, os, sys, time, urllib.request

BASE=os.environ["BASE_URL"]
stamp=int(time.time())
p=f=0

def check(label, cond):
    global p,f
    if cond:
        print(f"[PASS] {label}", flush=True); p+=1
    else:
        print(f"[FAIL] {label}", flush=True); f+=1

def req(method,path,payload=None):
    data=None
    headers={}
    if payload is not None:
        data=json.dumps(payload).encode()
        headers["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)
    with urllib.request.urlopen(r,timeout=15) as x:
        raw=x.read()
        ct=x.headers.get("Content-Type","")
        body=json.loads(raw) if raw and "application/json" in ct.lower() else raw.decode(errors="replace")
        return x.status,body,ct

home=req("POST","/api/teams",{
    "name":f"M12-D5 Home {stamp}",
    "short_name":"D5H",
    "primary_color":"#C8102E",
    "secondary_color":"#FFD100",
})[1]

away=req("POST","/api/teams",{
    "name":f"M12-D5 Away {stamp}",
    "short_name":"D5A",
    "primary_color":"#0057B8",
    "secondary_color":"#FFFFFF",
})[1]

game=req("POST","/api/games",{
    "name":f"M12-D5 Branded Control {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]

req("POST",f"/api/games/{game['id']}/lifecycle",{})
req("POST",f"/api/games/{game['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})

status,page,ct=req("GET",f"/control/games/{game['id']}")

check("Control Center route returns HTML",status==200 and "text/html" in ct.lower())
check("M12-D5 marker present","M12-D5" in page)
check("Home branding logo shell present",'id="home-control-logo-shell"' in page)
check("Away branding logo shell present",'id="away-control-logo-shell"' in page)
check("Home scoring branding shell present",'id="home-scoring-logo-shell"' in page)
check("Away scoring branding shell present",'id="away-scoring-logo-shell"' in page)
check("D5 dedicated CSS loaded",'/static/css/control-d5.css' in page)
check("D5 branding module loaded",'/static/js/control/control-branding.js' in page)

for token,label in [
    ('id="start-first-half-button"',"Lifecycle controls preserved"),
    ('id="home-goal-button"',"Home scoring preserved"),
    ('id="away-goal-button"',"Away scoring preserved"),
    ('id="home-scorer-select"',"Home scorer selector preserved"),
    ('id="away-scorer-select"',"Away scorer selector preserved"),
    ('id="connection-badge"',"Connection UI preserved"),
    ('/static/js/control/control.js',"Authoritative control module preserved"),
]:
    check(label,token in page)

print("========================================")
print(f"M12-D5 Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY

RC=$?
set -e
cat "$TMP"

P=$(grep -oP 'M12-D5 Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M12-D5 Control branding process passed" \
  || fail "M12-D5 Control branding process failed"

echo ""
echo "========================================"
echo "Running M12-D4 regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12d4.sh
D4_RC=$?
set -e

[ "$D4_RC" -eq 0 ] \
  && pass "M12-D4 regression passed" \
  || fail "M12-D4 regression failed"

echo ""
echo "========================================"
echo "Running M11-G Control/Overlay regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m11g.sh
M11G_RC=$?
set -e

[ "$M11G_RC" -eq 0 ] \
  && pass "M11-G Control/Overlay regression passed" \
  || fail "M11-G Control/Overlay regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M12-D5 VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M12-D5 VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
