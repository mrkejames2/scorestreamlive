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
echo "ScoreStreamLive M12-B Game Creation + Team Selection Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /health/live \
  /health/ready \
  /info \
  /games \
  /static/css/games.css \
  /static/js/games/index.js
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

PAGE=$(curl -fsS "${BASE_URL}/games")
JS=$(curl -fsS "${BASE_URL}/static/js/games/index.js")
CSS=$(curl -fsS "${BASE_URL}/static/css/games.css")

echo ""
echo "========================================"
echo "M12-B Static Capability Checks"
echo "========================================"

grep -Fq 'id="new-game-button"' <<<"$PAGE" \
  && pass "New Game button present" || fail "New Game button missing"

grep -Fq 'id="new-game-form"' <<<"$PAGE" \
  && pass "New Game form present" || fail "New Game form missing"

grep -Fq 'id="game-name"' <<<"$PAGE" \
  && pass "Game Name input present" || fail "Game Name input missing"

grep -Fq 'id="home-team-search"' <<<"$PAGE" \
  && pass "Home Team search present" || fail "Home Team search missing"

grep -Fq 'id="away-team-search"' <<<"$PAGE" \
  && pass "Away Team search present" || fail "Away Team search missing"

grep -Fq 'const MAX_TEAM_RESULTS = 12;' <<<"$JS" \
  && pass "Team search results are bounded" || fail "Team search result cap missing"

grep -Fq 'api("/api/teams")' <<<"$JS" \
  && pass "M12-A bulk Team loading preserved" || fail "Bulk Team loading missing"

grep -Fq 'const MAX_VISIBLE_GAMES = 25;' <<<"$JS" \
  && pass "M12-A recent-game cap preserved" || fail "Recent-game cap missing"

grep -Fq 'const MAX_CONCURRENT_GAMES = 6;' <<<"$JS" \
  && pass "M12-A bounded hydration preserved" || fail "Bounded hydration missing"

grep -Fq 'method: "POST"' <<<"$JS" \
  && grep -Fq 'api("/api/games"' <<<"$JS" \
  && pass "M12-B creates Game through REST" || fail "Game POST implementation missing"

grep -Fq 'Home and Away Team must be different.' <<<"$JS" \
  && pass "Same-team selection is rejected" || fail "Same-team guard missing"

grep -Fq 'state.selectedHomeId' <<<"$JS" \
  && grep -Fq 'state.selectedAwayId' <<<"$JS" \
  && pass "Explicit Home/Away selection state exists" || fail "Team selection state missing"

if grep -Eq 'api\(`/api/teams/\$\{.*\}`\)' <<<"$JS"; then
  fail "Per-game Team GET regression detected"
else
  pass "No per-game Team GET regression"
fi

if grep -Fq 'clock:tick' <<<"$JS"; then
  fail "clock:tick introduced"
else
  pass "No clock:tick consumer introduced"
fi

grep -Fq '.new-game-panel' <<<"$CSS" \
  && pass "New Game responsive styling present" || fail "New Game styling missing"

TMP=$(mktemp)
set +e
docker compose exec -T -e BASE_URL="$BASE_URL" app python3 - <<'PY' >"$TMP" 2>&1
import json, os, sys, time, urllib.error, urllib.request

BASE=os.environ["BASE_URL"]
stamp=int(time.time())
p=f=0

def check(label, cond):
    global p,f
    if cond:
        print(f"[PASS] {label}", flush=True); p+=1
    else:
        print(f"[FAIL] {label}", flush=True); f+=1

def req(method,path,payload=None,allow=False):
    data=None
    headers={}
    if payload is not None:
        data=json.dumps(payload).encode()
        headers["Content-Type"]="application/json"

    r=urllib.request.Request(
        BASE+path,
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(r,timeout=15) as x:
            raw=x.read()
            ct=x.headers.get("Content-Type","")
            body=(
                json.loads(raw)
                if raw and "application/json" in ct.lower()
                else raw.decode(errors="replace")
            )
            return x.status,body,ct
    except urllib.error.HTTPError as e:
        raw=e.read()
        try:
            body=json.loads(raw) if raw else None
        except Exception:
            body=raw.decode(errors="replace")
        if allow:
            return e.code,body,e.headers.get("Content-Type","")
        raise

home=req("POST","/api/teams",{
    "name":f"M12B Home {stamp}",
    "short_name":"M12H",
})[1]

away=req("POST","/api/teams",{
    "name":f"M12B Away {stamp}",
    "short_name":"M12A",
})[1]

status,game,_=req("POST","/api/games",{
    "name":f"M12-B GUI Contract {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})

check("Game REST creation returns success",status in (200,201))
check("Created Game has requested name",game["name"]==f"M12-B GUI Contract {stamp}")
check("Created Game has requested Home Team",game["home_team_id"]==home["id"])
check("Created Game has requested Away Team",game["away_team_id"]==away["id"])
check("Created Game score begins 0-0",
      game.get("home_score")==0 and game.get("away_score")==0)

_,games,_=req("GET","/api/games")
check("Created Game appears in collection",
      any(x.get("id")==game["id"] for x in games))

code,_,_=req("GET",f"/api/games/{game['id']}/lifecycle",allow=True)
check("M12-B does not auto-create lifecycle",code==404)

code,_,_=req("GET",f"/api/games/{game['id']}/clock",allow=True)
check("M12-B does not auto-create clock",code==404)

print("========================================")
print(f"M12-B Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY
RC=$?
set -e

cat "$TMP"
P=$(grep -oP 'M12-B Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)
PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M12-B Game creation process passed" \
  || fail "M12-B Game creation process failed"

echo ""
echo "========================================"
echo "Running M12-A regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12a.sh
M12A_RC=$?
set -e

[ "$M12A_RC" -eq 0 ] \
  && pass "M12-A regression passed" \
  || fail "M12-A regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M12-B VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M12-B VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
