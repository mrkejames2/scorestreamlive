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
echo "ScoreStreamLive M12-E Roster Management for Setup"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /health/live \
  /health/ready \
  /info \
  /games \
  /static/css/game-setup.css \
  /static/js/games/setup.js
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

JS=$(curl -fsS "${BASE_URL}/static/js/games/setup.js")
CSS=$(curl -fsS "${BASE_URL}/static/css/game-setup.css")
GAMES_JS=$(curl -fsS "${BASE_URL}/static/js/games/index.js")
GAMES_PAGE=$(curl -fsS "${BASE_URL}/games")

echo ""
echo "========================================"
echo "M12-E Static Capability Checks"
echo "========================================"

grep -Fq '/api/games/${gameId}' <<<"$JS" \
  && pass "Setup reads authoritative Game" \
  || fail "Setup Game read missing"

grep -Fq '/api/teams/${game.home_team_id}' <<<"$JS" \
  && grep -Fq '/api/teams/${game.away_team_id}' <<<"$JS" \
  && pass "Setup reads authoritative Home/Away Teams" \
  || fail "Setup Team reads missing"

grep -Fq '/api/teams/${game.home_team_id}/players' <<<"$JS" \
  && grep -Fq '/api/teams/${game.away_team_id}/players' <<<"$JS" \
  && pass "Setup reads both authoritative rosters" \
  || fail "Setup roster reads missing"

grep -Fq 'api("/api/players"' <<<"$JS" \
  && grep -Fq 'method: "POST"' <<<"$JS" \
  && pass "Player creation uses existing Player REST API" \
  || fail "Player REST creation orchestration missing"

grep -Fq 'await refreshRoster(side)' <<<"$JS" \
  && pass "Created Player triggers authoritative roster refresh" \
  || fail "Post-create roster refresh missing"

grep -Fq 'jerseyNumber < 0' <<<"$JS" \
  && grep -Fq 'jerseyNumber > 999' <<<"$JS" \
  && pass "UI mirrors Player jersey range 0-999" \
  || fail "Jersey range validation missing"

grep -Fq 'team?.logo_url' <<<"$JS" \
  && grep -Fq 'team?.primary_color' <<<"$JS" \
  && grep -Fq 'team?.secondary_color' <<<"$JS" \
  && pass "M12-D Team branding reused in setup" \
  || fail "Team branding presentation missing"

if grep -Eq 'method:[[:space:]]*"(PATCH|PUT|DELETE)"|method:[[:space:]]*'\''(PATCH|PUT|DELETE)'\''' <<<"$JS"; then
  fail "M12-E introduced out-of-scope Player mutation"
else
  pass "M12-E scope remains review + create only"
fi

if grep -Fq 'clock:tick' <<<"$JS"; then
  fail "M12-E consumes clock:tick"
else
  pass "M12-E consumes no clock:tick"
fi

grep -Fq '.roster-grid' <<<"$CSS" \
  && grep -Fq '.player-form' <<<"$CSS" \
  && grep -Fq '@media (max-width: 620px)' <<<"$CSS" \
  && pass "Roster management responsive styling exists" \
  || fail "Roster setup styling missing"

grep -Fq 'setup-link' <<<"$GAMES_PAGE" \
  && pass "Game Management exposes Manage Roster action" \
  || fail "Manage Roster action missing from Game Management"

grep -Fq '/games/${game.id}/setup' <<<"$GAMES_JS" \
  && pass "Manage Roster action is bound to Game ID" \
  || fail "Manage Roster Game-ID link missing"

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

    request=urllib.request.Request(
        BASE+path,
        data=data,
        headers=headers,
        method=method,
    )

    with urllib.request.urlopen(request,timeout=15) as response:
        raw=response.read()
        ct=response.headers.get("Content-Type","")
        body=(
            json.loads(raw)
            if raw and "application/json" in ct.lower()
            else raw.decode(errors="replace")
        )
        return response.status,body,ct

home=req("POST","/api/teams",{
    "name":f"M12-E Home {stamp}",
    "short_name":"EHOME",
    "primary_color":"#C8102E",
    "secondary_color":"#FFD100",
})[1]

away=req("POST","/api/teams",{
    "name":f"M12-E Away {stamp}",
    "short_name":"EAWAY",
    "primary_color":"#0057B8",
    "secondary_color":"#FFFFFF",
})[1]

game=req("POST","/api/games",{
    "name":f"M12-E Roster Setup {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]

status,page,ct=req("GET",f"/games/{game['id']}/setup")

check("Game Setup route returns HTML",status==200 and "text/html" in ct.lower())
check("M12-E marker present","M12-E" in page)
check("Home roster UI present",'id="home-roster-list"' in page)
check("Away roster UI present",'id="away-roster-list"' in page)
check("Home add-player form present",'id="home-player-form"' in page)
check("Away add-player form present",'id="away-player-form"' in page)
check("Dedicated setup CSS loaded",'/static/css/game-setup.css' in page)
check("Dedicated setup JS loaded",'/static/js/games/setup.js' in page)

home_player=req("POST","/api/players",{
    "team_id":home["id"],
    "first_name":"Alex",
    "last_name":"Home",
    "jersey_number":9,
})[1]

away_player=req("POST","/api/players",{
    "team_id":away["id"],
    "first_name":"Jordan",
    "last_name":"Away",
    "jersey_number":14,
})[1]

home_roster=req("GET",f"/api/teams/{home['id']}/players")[1]
away_roster=req("GET",f"/api/teams/{away['id']}/players")[1]

check(
    "Home Player persists in authoritative roster",
    any(x.get("id")==home_player["id"] for x in home_roster),
)

check(
    "Away Player persists in authoritative roster",
    any(x.get("id")==away_player["id"] for x in away_roster),
)

check(
    "Home jersey number persists",
    any(
        x.get("id")==home_player["id"] and x.get("jersey_number")==9
        for x in home_roster
    ),
)

check(
    "Away jersey number persists",
    any(
        x.get("id")==away_player["id"] and x.get("jersey_number")==14
        for x in away_roster
    ),
)

no_jersey=req("POST","/api/players",{
    "team_id":home["id"],
    "first_name":"Taylor",
    "last_name":"NoJersey",
    "jersey_number":None,
})[1]

fresh_home=req("GET",f"/api/teams/{home['id']}/players")[1]

check(
    "Optional jersey number remains supported",
    any(
        x.get("id")==no_jersey["id"] and x.get("jersey_number") is None
        for x in fresh_home
    ),
)

print("========================================")
print(f"M12-E Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY

RC=$?
set -e

cat "$TMP"

P=$(grep -oP 'M12-E Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M12-E roster-management process passed" \
  || fail "M12-E roster-management process failed"

echo ""
echo "========================================"
echo "Running M12-D6 cumulative regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12d6.sh
D6_RC=$?
set -e

[ "$D6_RC" -eq 0 ] \
  && pass "M12-D6 cumulative regression passed" \
  || fail "M12-D6 cumulative regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M12-E VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M12-E VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
