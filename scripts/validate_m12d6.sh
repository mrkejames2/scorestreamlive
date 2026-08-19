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
echo "ScoreStreamLive M12-D6 Branded Broadcast Overlay + M12-D Final Gate"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /health/live \
  /health/ready \
  /info \
  /static/css/overlay.css \
  /static/css/overlay-d6.css \
  /static/js/overlay/overlay.js \
  /static/vendor/socket.io.min.js
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

JS=$(curl -fsS "${BASE_URL}/static/js/overlay/overlay.js")
CSS=$(curl -fsS "${BASE_URL}/static/css/overlay-d6.css")

echo ""
echo "========================================"
echo "M12-D6 Static Branding Checks"
echo "========================================"

grep -Fq 'team?.logo_url' <<<"$JS" \
  && pass "Overlay consumes persisted Team logo_url" \
  || fail "Overlay Team logo_url consumer missing"

grep -Fq 'team?.primary_color' <<<"$JS" \
  && grep -Fq 'team?.secondary_color' <<<"$JS" \
  && pass "Overlay consumes Team colors" \
  || fail "Overlay Team color consumers missing"

grep -Fq 'function teamInitials' <<<"$JS" \
  && grep -Fq 'logo.onerror' <<<"$JS" \
  && pass "Overlay logo has initials fallback" \
  || fail "Overlay logo fallback missing"

grep -Fq 'applyOverlayTeamBrand("home", state.homeTeam)' <<<"$JS" \
  && grep -Fq 'applyOverlayTeamBrand("away", state.awayTeam)' <<<"$JS" \
  && pass "Home/Away branding renders from authoritative Team state" \
  || fail "Home/Away branding render path missing"

grep -Fq 'applyGoalBannerBrand(team)' <<<"$JS" \
  && pass "Goal banner inherits scoring Team branding" \
  || fail "Goal banner Team branding missing"

grep -Fq 'const CLOCK_RESYNC_MS = 5000;' <<<"$JS" \
  && grep -Fq 'performance.now()' <<<"$JS" \
  && pass "M11 precision clock architecture preserved" \
  || fail "M11 precision clock architecture regressed"

grep -Fq 'scoring_event:created' <<<"$JS" \
  && grep -Fq 'showGoalBanner(payload)' <<<"$JS" \
  && pass "M11 goal presentation preserved" \
  || fail "M11 goal presentation regressed"

grep -Fq 'showMatchStateBanner(phase)' <<<"$JS" \
  && grep -Fq 'lastPresentedPhase' <<<"$JS" \
  && pass "M11 lifecycle presentation/replay protection preserved" \
  || fail "M11 lifecycle presentation regressed"

if grep -Eq 'method:[[:space:]]*"(POST|PATCH|PUT|DELETE)"|method:[[:space:]]*'\''(POST|PATCH|PUT|DELETE)'\''' <<<"$JS"; then
  fail "Overlay introduced mutation request"
else
  pass "Overlay remains read-only"
fi

if grep -Fq 'clock:tick' <<<"$JS"; then
  fail "Overlay consumes clock:tick"
else
  pass "Overlay consumes no clock:tick"
fi

grep -Fq '.overlay-team-logo-shell' <<<"$CSS" \
  && grep -Fq '.branded-overlay-team' <<<"$CSS" \
  && grep -Fq '.goal-banner-logo-shell' <<<"$CSS" \
  && pass "Broadcast Team/Goal branding CSS exists" \
  || fail "Broadcast branding CSS missing"

grep -Fq 'var(--team-primary)' <<<"$CSS" \
  && grep -Fq 'var(--team-secondary)' <<<"$CSS" \
  && pass "Broadcast presentation uses Team color variables" \
  || fail "Broadcast Team color presentation missing"

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
    "name":f"M12-D6 Home {stamp}",
    "short_name":"D6H",
    "primary_color":"#C8102E",
    "secondary_color":"#FFD100",
})[1]

away=req("POST","/api/teams",{
    "name":f"M12-D6 Away {stamp}",
    "short_name":"D6A",
    "primary_color":"#0057B8",
    "secondary_color":"#FFFFFF",
})[1]

game=req("POST","/api/games",{
    "name":f"M12-D6 Branded Broadcast {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]

req("POST",f"/api/games/{game['id']}/lifecycle",{})
req("POST",f"/api/games/{game['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})

status,page,ct=req("GET",f"/overlay/games/{game['id']}")

check("Overlay route returns HTML",status==200 and "text/html" in ct.lower())
check("Home overlay logo shell present",'id="home-overlay-logo-shell"' in page)
check("Away overlay logo shell present",'id="away-overlay-logo-shell"' in page)
check("Goal banner logo shell present",'id="goal-banner-logo-shell"' in page)
check("D6 dedicated CSS loaded",'/static/css/overlay-d6.css' in page)
check("M11 overlay JS preserved",'/static/js/overlay/overlay.js' in page)
check("Socket.IO client preserved",'/static/vendor/socket.io.min.js' in page)
check("Goal banner preserved",'id="goal-banner"' in page)
check("Match-state banner preserved",'id="match-state-banner"' in page)
check("Scoreboard preserved",'id="overlay-scoreboard"' in page)

fresh_home=req("GET",f"/api/teams/{home['id']}")[1]
fresh_away=req("GET",f"/api/teams/{away['id']}")[1]

check("Home branding remains persisted",
      fresh_home.get("primary_color")=="#C8102E"
      and fresh_home.get("secondary_color")=="#FFD100")
check("Away branding remains persisted",
      fresh_away.get("primary_color")=="#0057B8"
      and fresh_away.get("secondary_color")=="#FFFFFF")

print("========================================")
print(f"M12-D6 Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY

RC=$?
set -e
cat "$TMP"

P=$(grep -oP 'M12-D6 Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M12-D6 branded broadcast process passed" \
  || fail "M12-D6 branded broadcast process failed"

echo ""
echo "========================================"
echo "Running M12-D5 regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12d5.sh
D5_RC=$?
set -e

[ "$D5_RC" -eq 0 ] \
  && pass "M12-D5 cumulative regression passed" \
  || fail "M12-D5 cumulative regression failed"

echo ""
echo "========================================"
echo "Running M11-G broadcast release regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m11g.sh
M11G_RC=$?
set -e

[ "$M11G_RC" -eq 0 ] \
  && pass "M11-G broadcast regression passed" \
  || fail "M11-G broadcast regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M12-D6 FINAL VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  echo "M12-D AUTOMATED ACCEPTANCE = PASS"
  exit 0
else
  echo "M12-D6 FINAL VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
