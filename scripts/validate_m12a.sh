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
echo "ScoreStreamLive M12-A Game Management Home Validation"
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

JS=$(curl -fsS "${BASE_URL}/static/js/games/index.js")

echo ""
echo "========================================"
echo "M12-A Scalability Architecture Checks"
echo "========================================"

grep -Fq 'const MAX_VISIBLE_GAMES = 25;' <<<"$JS" \
  && pass "Recent-game display cap is 25" \
  || fail "Recent-game display cap is missing or changed"

grep -Fq 'const MAX_CONCURRENT_GAMES = 6;' <<<"$JS" \
  && pass "Bounded hydration concurrency is 6" \
  || fail "Bounded hydration concurrency is missing or changed"

grep -Fq 'api("/api/teams")' <<<"$JS" \
  && pass "Teams are loaded once through collection API" \
  || fail "Bulk Team collection load missing"

grep -Fq 'buildTeamMap' <<<"$JS" \
  && pass "Bulk Team collection is indexed locally" \
  || fail "Local Team map missing"

grep -Fq 'sortedGames.slice(' <<<"$JS" \
  && grep -Fq 'MAX_VISIBLE_GAMES' <<<"$JS" \
  && pass "Only recent games are selected for hydration" \
  || fail "Recent-game slice strategy missing"

grep -Fq 'mapWithConcurrency' <<<"$JS" \
  && pass "Bounded concurrency helper preserved" \
  || fail "Bounded concurrency helper missing"

if grep -Eq 'api\(`/api/teams/\$\{.*\}`\)' <<<"$JS"; then
  fail "Per-game Team GET pattern detected"
else
  pass "No per-game Team GET pattern"
fi

if grep -Fq 'games.map((game) => hydrateGame(game))' <<<"$JS"; then
  fail "Unbounded all-game hydration pattern detected"
else
  pass "No unbounded all-game hydration"
fi

grep -Fq 'Older historical/test games are not loaded into this view.' <<<"$JS" \
  && pass "Large-history informational notice preserved" \
  || fail "Large-history informational notice missing"

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
        print(f"[PASS] {label}", flush=True)
        p+=1
    else:
        print(f"[FAIL] {label}", flush=True)
        f+=1

def req(method,path,payload=None):
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
    "name":"Saginaw United",
    "short_name":"SAG",
})[1]

away=req("POST","/api/teams",{
    "name":"Midland City",
    "short_name":"MID",
})[1]

game=req("POST","/api/games",{
    "name":f"M12-A Game Management {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]

req("POST",f"/api/games/{game['id']}/lifecycle",{})

req("POST",f"/api/games/{game['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})

_,page,ct=req("GET","/games")

check(
    "Game Management returns HTML",
    "text/html" in ct.lower(),
)

check(
    "M12-A Games heading present",
    ">Games<" in page,
)

check(
    "M12-A Game Management heading present",
    "Game Management" in page,
)

check(
    "M12-A summary total present",
    'id="summary-total"' in page,
)

check(
    "M12-A summary active present",
    'id="summary-active"' in page,
)

check(
    "M12-A summary completed present",
    'id="summary-completed"' in page,
)

check(
    "M12-A game card template present",
    'id="game-card-template"' in page,
)

check(
    "M12-A loads dedicated CSS",
    '/static/css/games.css' in page,
)

check(
    "M12-A loads dedicated JS",
    '/static/js/games/index.js' in page,
)

_,js,_=req("GET","/static/js/games/index.js")

check(
    "M12-A reads Game collection",
    'api("/api/games")' in js,
)

check(
    "M12-A reads Team collection once",
    'api("/api/teams")' in js,
)

check(
    "M12-A builds Team map",
    "buildTeamMap" in js,
)

check(
    "M12-A reads lifecycle state",
    "/lifecycle" in js,
)

check(
    "M12-A reads clock state",
    "/clock" in js,
)

check(
    "M12-A handles uninitialized lifecycle/clock",
    "allow404" in js,
)

check(
    "M12-A links Control Center",
    "/control/games/" in js,
)

check(
    "M12-A links Broadcast Overlay",
    "/overlay/games/" in js,
)

check(
    "M12-A limits visible games",
    "MAX_VISIBLE_GAMES = 25" in js,
)

check(
    "M12-A bounds hydration concurrency",
    "MAX_CONCURRENT_GAMES = 6" in js
    and "mapWithConcurrency" in js,
)

# M12-B intentionally adds POST /api/games.
# Preserve the permanent regression boundary by allowing POST,
# while still rejecting PATCH / PUT / DELETE mutations here.
forbidden_methods = (
    'method: "PATCH"',
    "method: 'PATCH'",
    'method: "PUT"',
    "method: 'PUT'",
    'method: "DELETE"',
    "method: 'DELETE'",
)

check(
    "M12-A/M12-B introduces no forbidden PATCH/PUT/DELETE mutation",
    not any(marker in js for marker in forbidden_methods),
)

check(
    "M12-A contains no client-side score arithmetic",
    "home_score + 1" not in js
    and "away_score + 1" not in js,
)

check(
    "M12-A consumes no clock:tick",
    "clock:tick" not in js,
)

_,games,_=req("GET","/api/games")

check(
    "Existing Game list API still returns collection",
    isinstance(games,list),
)

check(
    "M12-A test Game appears in Game collection",
    any(x.get("id")==game["id"] for x in games),
)

_,fresh,_=req("GET",f"/api/games/{game['id']}")

check(
    "M12-A authoritative score remains server-owned",
    fresh.get("home_score")==0
    and fresh.get("away_score")==0,
)

print("========================================")
print(f"M12-A Python Tests Passed: {p} Failed: {f}")
print("========================================")

sys.exit(1 if f else 0)
PY

RC=$?
set -e

cat "$TMP"

P=$(grep -oP 'M12-A Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)

PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))

rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M12-A Game Management process passed" \
  || fail "M12-A Game Management process failed"

echo ""
echo "========================================"
echo "Running M11-G final regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m11g.sh
M11_RC=$?
set -e

[ "$M11_RC" -eq 0 ] \
  && pass "M11-G regression passed" \
  || fail "M11-G regression failed"

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo "M12-A VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M12-A VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi