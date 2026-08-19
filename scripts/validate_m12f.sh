#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://192.168.1.196:8000}"
export BASE_URL

PASS=0
FAIL=0
FAILURES=()

pass(){ PASS=$((PASS+1)); }
fail(){ FAIL=$((FAIL+1)); FAILURES+=("$1"); }

check_http() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass || fail "${path} HTTP ${code}"
}

check_http /health/live
check_http /health/ready
check_http /info
check_http /games
check_http /static/css/game-detail.css
check_http /static/js/games/detail.js

JS=$(curl -fsS "${BASE_URL}/static/js/games/detail.js")
CSS=$(curl -fsS "${BASE_URL}/static/css/game-detail.css")
GAMES=$(curl -fsS "${BASE_URL}/games")
GAMES_JS=$(curl -fsS "${BASE_URL}/static/js/games/index.js")

grep -Fq '/api/games/${gameId}' <<<"$JS" && pass || fail "Launch Hub authoritative Game read missing"
grep -Fq '/api/teams/${game.home_team_id}' <<<"$JS" \
  && grep -Fq '/api/teams/${game.away_team_id}' <<<"$JS" \
  && pass || fail "Launch Hub authoritative Team reads missing"
grep -Fq '/players' <<<"$JS" && pass || fail "Launch Hub roster summary reads missing"
grep -Fq '/lifecycle' <<<"$JS" && grep -Fq '/clock' <<<"$JS" \
  && pass || fail "Launch Hub lifecycle/clock reads missing"
grep -Fq 'allow404' <<<"$JS" && pass || fail "Launch Hub uninitialized-state handling missing"
grep -Fq '/control/games/${game.id}' <<<"$JS" && pass || fail "Control Center launch link missing"
grep -Fq '/overlay/games/${game.id}' <<<"$JS" && pass || fail "Broadcast Overlay launch link missing"
grep -Fq '/games/${game.id}/setup' <<<"$JS" && pass || fail "Roster Management launch link missing"
grep -Fq 'navigator.clipboard.writeText' <<<"$JS" && pass || fail "Copy Overlay URL capability missing"
grep -Fq 'team?.logo_url' <<<"$JS" \
  && grep -Fq 'team?.primary_color' <<<"$JS" \
  && pass || fail "Team branding missing from Launch Hub"
grep -Fq '.match-hero' <<<"$CSS" \
  && grep -Fq '.primary-launch-grid' <<<"$CSS" \
  && grep -Fq '@media (max-width: 620px)' <<<"$CSS" \
  && pass || fail "Launch Hub responsive presentation missing"
grep -Fq 'hub-link' <<<"$GAMES" && pass || fail "Game Management Open Game action missing"
grep -Fq '/games/${game.id}`' <<<"$GAMES_JS" && pass || fail "Open Game action Game-ID binding missing"

if grep -Eq 'method:[[:space:]]*"(POST|PATCH|PUT|DELETE)"|method:[[:space:]]*'\''(POST|PATCH|PUT|DELETE)'\''' <<<"$JS"; then
  fail "Launch Hub introduced mutation request"
else
  pass
fi

if grep -Fq 'clock:tick' <<<"$JS"; then
  fail "Launch Hub consumes clock:tick"
else
  pass
fi

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
fails=[]

def check(label, cond):
    global p,f
    if cond:
        p+=1
    else:
        f+=1
        fails.append(label)

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
        body=(
            json.loads(raw)
            if raw and "application/json" in ct.lower()
            else raw.decode(errors="replace")
        )
        return x.status,body,ct

home=req("POST","/api/teams",{
    "name":f"M12-F Home {stamp}",
    "short_name":"FHOME",
    "primary_color":"#C8102E",
    "secondary_color":"#FFD100",
})[1]

away=req("POST","/api/teams",{
    "name":f"M12-F Away {stamp}",
    "short_name":"FAWAY",
    "primary_color":"#0057B8",
    "secondary_color":"#FFFFFF",
})[1]

game=req("POST","/api/games",{
    "name":f"M12-F Launch Hub {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]

req("POST",f"/api/games/{game['id']}/lifecycle",{})
req("POST",f"/api/games/{game['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})

req("POST","/api/players",{
    "team_id":home["id"],
    "first_name":"Alex",
    "last_name":"Home",
    "jersey_number":9,
})

req("POST","/api/players",{
    "team_id":away["id"],
    "first_name":"Jordan",
    "last_name":"Away",
    "jersey_number":14,
})

status,page,ct=req("GET",f"/games/{game['id']}")

check("Game Detail route returns HTML",status==200 and "text/html" in ct.lower())
check("M12-F marker present","M12-F" in page)
check("Match hero present",'id="match-hero"' in page)
check("Control Center action present",'id="control-link"' in page)
check("Broadcast Overlay action present",'id="overlay-link"' in page)
check("Manage Rosters action present",'id="roster-link"' in page)
check("Copy Overlay URL action present",'id="copy-overlay-url"' in page)
check("Lifecycle readiness present",'id="lifecycle-readiness"' in page)
check("Clock readiness present",'id="clock-readiness"' in page)
check("Home roster count present",'id="home-roster-count"' in page)
check("Away roster count present",'id="away-roster-count"' in page)
check("Dedicated detail CSS loaded",'/static/css/game-detail.css' in page)
check("Dedicated detail JS loaded",'/static/js/games/detail.js' in page)

for label in fails:
    print(f"[FAIL] {label}")

print(f"LOCAL_PASS={p}")
print(f"LOCAL_FAIL={f}")
sys.exit(1 if f else 0)
PY

PY_RC=$?
set -e

P=$(grep -oP 'LOCAL_PASS=\K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'LOCAL_FAIL=\K[0-9]+' "$TMP" | tail -1 || true)

PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))

while IFS= read -r line; do
  [ -n "$line" ] && FAILURES+=("${line#\[FAIL\] }")
done < <(grep '^\[FAIL\]' "$TMP" || true)

rm -f "$TMP"

if [ "$PY_RC" -ne 0 ] && [ "${F:-0}" -eq 0 ]; then
  fail "M12-F dynamic validation process failed unexpectedly"
fi

# Run cumulative M12-E regression silently.
REG_TMP=$(mktemp)
set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12e.sh >"$REG_TMP" 2>&1
REG_RC=$?
set -e

echo "========================================"
echo "ScoreStreamLive M12-F Regression Summary"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo "M12-F ............... PASS   ${PASS} passed / 0 failed"
else
  echo "M12-F ............... FAIL   ${PASS} passed / ${FAIL} failed"
fi

if [ "$REG_RC" -eq 0 ]; then
  echo "M12-E cumulative .... PASS"
else
  echo "M12-E cumulative .... FAIL"
  FAILURES+=("M12-E cumulative regression failed")

  while IFS= read -r line; do
    [ -n "$line" ] && FAILURES+=("${line}")
  done < <(
    grep -E '^\[FAIL\]|VALIDATION FAILED|AUTOMATED ACCEPTANCE = FAIL' "$REG_TMP" \
      | tail -40 || true
  )
fi

rm -f "$REG_TMP"

TOTAL_FAIL=$FAIL
[ "$REG_RC" -eq 0 ] || TOTAL_FAIL=$((TOTAL_FAIL+1))

echo "========================================"

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo "OVERALL ............. PASS"
  echo "Failed Components: None"
  echo "========================================"
  echo "M12-F VALIDATION PASSED"
  exit 0
fi

echo "OVERALL ............. FAIL"
echo ""
echo "FAILED COMPONENTS"
echo "-----------------"

printf '%s\n' "${FAILURES[@]}" | awk 'NF && !seen[$0]++ {print "- "$0}'

echo "========================================"
echo "M12-F VALIDATION FAILED"
exit 1
