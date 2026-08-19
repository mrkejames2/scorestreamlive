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
progress(){ echo "[$1/10] $2"; }

check_http() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass || fail "${path} HTTP ${code}"
}

STATE_TMP=$(mktemp)
REG_TMP=$(mktemp)
trap 'rm -f "$STATE_TMP" "$REG_TMP"' EXIT

progress 1 "Checking application health and M12-G assets..."
check_http /health/live
check_http /health/ready
check_http /info
check_http /games
check_http /static/css/games-g.css
check_http /static/css/game-detail-g.css

progress 2 "Validating resume/recovery UI capabilities..."
GAMES_JS=$(curl -fsS "${BASE_URL}/static/js/games/index.js")
DETAIL_JS=$(curl -fsS "${BASE_URL}/static/js/games/detail.js")
GAMES_PAGE=$(curl -fsS "${BASE_URL}/games")

[[ "$GAMES_JS" == *'card.dataset.resumeState'* ]] && pass || fail "Game cards do not expose resume state"
[[ "$GAMES_JS" == *'Resume Game'* ]] && pass || fail "Active-game Resume Game action missing"
[[ "$GAMES_JS" == *'Review Game'* ]] && pass || fail "Completed-game Review Game action missing"
[[ "$GAMES_PAGE" == *'resume-indicator'* ]] && pass || fail "Game Management resume indicator missing"
[[ "$DETAIL_JS" == *'renderRecoveryProof'* ]] && pass || fail "Game Hub recovery proof missing"
[[ "$DETAIL_JS" == *'Resume Control Center'* ]] && pass || fail "Game Hub Resume Control Center UX missing"

if grep -Eq 'localStorage|sessionStorage' <<<"$GAMES_JS$DETAIL_JS"; then
  fail "Game Management/Game Hub depend on browser storage"
else
  pass
fi

progress 3 "Creating recovery fixture and authoritative match state..."
set +e
python3 - <<'PY' >"$STATE_TMP" 2>&1
import json, os, sys, time, urllib.request

BASE=os.environ["BASE_URL"]
stamp=int(time.time())

def req(method,path,payload=None):
    data=None
    headers={"Accept":"application/json"}
    if payload is not None:
        data=json.dumps(payload).encode()
        headers["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)
    with urllib.request.urlopen(r,timeout=20) as x:
        raw=x.read()
        ct=x.headers.get("Content-Type","")
        body=json.loads(raw) if raw and "application/json" in ct.lower() else raw.decode(errors="replace")
        return x.status,body

home=req("POST","/api/teams",{
    "name":f"M12-G Recovery Home {stamp}",
    "short_name":"GHOME",
    "primary_color":"#C8102E",
    "secondary_color":"#FFD100",
})[1]
away=req("POST","/api/teams",{
    "name":f"M12-G Recovery Away {stamp}",
    "short_name":"GAWAY",
    "primary_color":"#0057B8",
    "secondary_color":"#FFFFFF",
})[1]
game=req("POST","/api/games",{
    "name":f"M12-G Recovery Match {stamp}",
    "home_team_id":home["id"],
    "away_team_id":away["id"],
})[1]
lifecycle=req("POST",f"/api/games/{game['id']}/lifecycle",{})[1]
clock=req("POST",f"/api/games/{game['id']}/clock",{
    "mode":"count_up",
    "duration_seconds":2700,
})[1]
home_player=req("POST","/api/players",{
    "team_id":home["id"],
    "first_name":"Alex",
    "last_name":"Recovery",
    "jersey_number":9,
})[1]
away_player=req("POST","/api/players",{
    "team_id":away["id"],
    "first_name":"Jordan",
    "last_name":"Recovery",
    "jersey_number":14,
})[1]
transition=req("POST",f"/api/games/{game['id']}/lifecycle/transition",{
    "action":"start_first_half",
    "expected_lifecycle_version":lifecycle["version"],
    "expected_clock_version":clock["version"],
})[1]
req("POST","/api/scoring-events",{
    "game_id":game["id"],
    "team_id":home["id"],
    "player_id":home_player["id"],
    "event_type":"goal",
})
time.sleep(2)
fresh_game=req("GET",f"/api/games/{game['id']}")[1]
fresh_clock=req("GET",f"/api/games/{game['id']}/clock")[1]

state={
    "game_id":game["id"],
    "home_team_id":home["id"],
    "away_team_id":away["id"],
    "home_player_id":home_player["id"],
    "away_player_id":away_player["id"],
    "expected_home_score":fresh_game["home_score"],
    "expected_away_score":fresh_game["away_score"],
    "expected_phase":transition["lifecycle"]["phase"],
    "elapsed_before_restart":fresh_clock["authoritative_elapsed_seconds"],
}
print("RECOVERY_STATE="+json.dumps(state,separators=(",",":")))
PY
CREATE_RC=$?
set -e

if [ "$CREATE_RC" -eq 0 ] && grep -q '^RECOVERY_STATE=' "$STATE_TMP"; then
  pass
else
  fail "Could not establish M12-G recovery fixture"
fi

RECOVERY_JSON=$(grep '^RECOVERY_STATE=' "$STATE_TMP" | tail -1 | sed 's/^RECOVERY_STATE=//' || true)

progress 4 "Verifying state is discoverable before restart..."
if [ -n "$RECOVERY_JSON" ]; then
  GAME_ID=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["game_id"])' "$RECOVERY_JSON")
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/games/${GAME_ID}" || true)
  [ "$code" = "200" ] && pass || fail "Game Hub unavailable before restart"

  if curl -fsS "${BASE_URL}/api/games" | python3 -c 'import json,sys; gid=sys.argv[1]; data=json.load(sys.stdin); raise SystemExit(0 if any(str(x.get("id"))==gid for x in data) else 1)' "$GAME_ID"; then
    pass
  else
    fail "Recovery game not rediscoverable from Game collection before restart"
  fi
else
  fail "Recovery state unavailable for pre-restart verification"
fi

progress 5 "Restarting the application container..."
set +e
docker compose restart app >/dev/null 2>&1
RESTART_RC=$?
set -e
[ "$RESTART_RC" -eq 0 ] && pass || fail "Application container restart failed"

progress 6 "Waiting for application readiness after restart..."
READY=0
for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health/ready" || true)
  if [ "$code" = "200" ]; then
    READY=1
    break
  fi
  sleep 1
done
[ "$READY" -eq 1 ] && pass || fail "Application did not become ready after restart"

progress 7 "Verifying PostgreSQL-backed game, roster, score, lifecycle, and clock recovery..."
if [ "$READY" -eq 1 ] && [ -n "$RECOVERY_JSON" ]; then
  export RECOVERY_JSON
  VERIFY_TMP=$(mktemp)
  set +e
  python3 - <<'PY' >"$VERIFY_TMP" 2>&1
import json, os, sys, urllib.request

BASE=os.environ["BASE_URL"]
s=json.loads(os.environ["RECOVERY_JSON"])
p=f=0
fails=[]

def check(label,cond):
    global p,f
    if cond: p+=1
    else: f+=1; fails.append(label)

def get(path):
    with urllib.request.urlopen(BASE+path,timeout=20) as x:
        raw=x.read(); ct=x.headers.get("Content-Type","")
        return json.loads(raw) if raw and "application/json" in ct.lower() else raw.decode(errors="replace")

games=get("/api/games")
game=get(f"/api/games/{s['game_id']}")
lifecycle=get(f"/api/games/{s['game_id']}/lifecycle")
clock=get(f"/api/games/{s['game_id']}/clock")
home_roster=get(f"/api/teams/{s['home_team_id']}/players")
away_roster=get(f"/api/teams/{s['away_team_id']}/players")
scoring=get(f"/api/games/{s['game_id']}/scoring-events")

check("Game rediscovered from collection after restart", any(str(x.get("id"))==s["game_id"] for x in games))
check("Authoritative Home score recovered", game.get("home_score")==s["expected_home_score"]==1)
check("Authoritative Away score recovered", game.get("away_score")==s["expected_away_score"]==0)
check("Lifecycle phase recovered", lifecycle.get("phase")==s["expected_phase"]=="first_half")
check("Running clock recovered", clock.get("status")=="running")
check("Clock includes restart interval", clock.get("authoritative_elapsed_seconds",0)>=s["elapsed_before_restart"])
check("Home roster recovered", any(str(x.get("id"))==s["home_player_id"] for x in home_roster))
check("Away roster recovered", any(str(x.get("id"))==s["away_player_id"] for x in away_roster))
check("Scoring history recovered", any(str(x.get("team_id"))==s["home_team_id"] and x.get("event_type")=="goal" for x in scoring))

for label in fails: print("[FAIL] "+label)
print(f"RECOVERY_PASS={p}")
print(f"RECOVERY_FAIL={f}")
sys.exit(1 if f else 0)
PY
  VERIFY_RC=$?
  set -e

  RP=$(grep -oP 'RECOVERY_PASS=\K[0-9]+' "$VERIFY_TMP" | tail -1 || true)
  RF=$(grep -oP 'RECOVERY_FAIL=\K[0-9]+' "$VERIFY_TMP" | tail -1 || true)
  PASS=$((PASS + ${RP:-0}))
  FAIL=$((FAIL + ${RF:-0}))
  while IFS= read -r line; do
    [ -n "$line" ] && FAILURES+=("${line#\[FAIL\] }")
  done < <(grep '^\[FAIL\]' "$VERIFY_TMP" || true)
  rm -f "$VERIFY_TMP"

  if [ "$VERIFY_RC" -ne 0 ] && [ "${RF:-0}" -eq 0 ]; then
    fail "Post-restart authoritative verification failed unexpectedly"
  fi
else
  fail "Post-restart authoritative verification could not run"
fi

progress 8 "Verifying browser-entry recovery surfaces..."
if [ "$READY" -eq 1 ] && [ -n "${GAME_ID:-}" ]; then
  for path in \
    "/games" \
    "/games/${GAME_ID}" \
    "/games/${GAME_ID}/setup" \
    "/control/games/${GAME_ID}" \
    "/overlay/games/${GAME_ID}"
  do
    code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
    [ "$code" = "200" ] && pass || fail "Recovery surface ${path} HTTP ${code}"
  done
else
  fail "Recovery surface verification skipped because app/game was unavailable"
fi

progress 9 "Running M12-F cumulative regression silently..."
set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12f.sh >"$REG_TMP" 2>&1
REG_RC=$?
set -e

if [ "$REG_RC" -ne 0 ]; then
  FAILURES+=("M12-F cumulative regression failed")
  while IFS= read -r line; do
    [ -n "$line" ] && FAILURES+=("$line")
  done < <(grep -E '^\[FAIL\]|VALIDATION FAILED|OVERALL[[:space:]]+\.\.\.\.\.\.\.\.\.\.\.\.\. FAIL' "$REG_TMP" | tail -40 || true)
fi

progress 10 "Building validation summary..."
echo "========================================"
echo "ScoreStreamLive M12-G Regression Summary"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo "M12-G ............... PASS   ${PASS} passed / 0 failed"
else
  echo "M12-G ............... FAIL   ${PASS} passed / ${FAIL} failed"
fi

if [ "$REG_RC" -eq 0 ]; then
  echo "M12-F cumulative .... PASS"
else
  echo "M12-F cumulative .... FAIL"
fi

echo "========================================"
TOTAL_FAIL=$FAIL
[ "$REG_RC" -eq 0 ] || TOTAL_FAIL=$((TOTAL_FAIL+1))

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo "OVERALL ............. PASS"
  echo "Failed Components: None"
  echo "========================================"
  echo "M12-G VALIDATION PASSED"
  exit 0
fi

echo "OVERALL ............. FAIL"
echo ""
echo "FAILED COMPONENTS"
echo "-----------------"
printf '%s\n' "${FAILURES[@]}" | awk 'NF && !seen[$0]++ {print "- "$0}'
echo "========================================"
echo "M12-G VALIDATION FAILED"
exit 1
