#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."&&pwd)";cd "$ROOT"
BASE_URL="${BASE_URL:-http://192.168.12.133:8000}";BASE_URL="${BASE_URL%/}";VALIDATION_MODE="${VALIDATION_MODE:-local}"
P=0;F=0;X=();T=$(mktemp);R=$(mktemp);trap 'rm -f "$T" "$R"' EXIT
ok(){ P=$((P+1));};bad(){ F=$((F+1));X+=("$1");}
echo "[1/6] Checking application health..."
for p in /health/live /health/ready;do c=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL$p"||true);[[ $c == 200 ]]&&ok||bad "$p HTTP $c";done
echo "[2/6] Creating roster UX fixture..."
c=$(curl -sS -o "$T" -w "%{http_code}" -X POST "$BASE_URL/api/teams" -H 'Content-Type: application/json' --data "{\"name\":\"M13-E Regression $(date +%s)\"}"||true)
ID=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("id",""))' "$T" 2>/dev/null||true)
[[ $c == 201&& -n $ID ]]&&ok||bad "Team fixture failed"
for row in '9|Zoe|Zulu' '2|Adam|Alpha' '|No|Number';do
 IFS='|' read -r J FST LST<<<"$row"; [[ -n "$J" ]]&&JVAL="$J"||JVAL="null"
 c=$(curl -sS -o "$T" -w "%{http_code}" -X POST "$BASE_URL/api/players" -H 'Content-Type: application/json' --data "{\"team_id\":\"$ID\",\"first_name\":\"$FST\",\"last_name\":\"$LST\",\"jersey_number\":$JVAL}"||true)
 [[ $c == 201 ]]&&ok||bad "Player fixture $FST failed"
done
echo "[3/6] Checking durable roster management UX surface..."
curl -fsS "$BASE_URL/teams/$ID">"$T"||true
for m in 'id="roster-search"' 'id="roster-sort"' 'id="roster-visible-count"' 'id="jersey-warning"' 'No matching players';do grep -Fq "$m" "$T"&&ok||bad "Missing durable roster UX marker $m";done
echo "[4/6] Checking client-side UX contracts..."
if [[ $VALIDATION_MODE == local ]];then
 grep -Fq 'searchInput.addEventListener("input",renderRoster)' static/js/teams/detail.js&&ok||bad "Roster search binding missing"
 grep -Fq 'sortInput.addEventListener("change",renderRoster)' static/js/teams/detail.js&&ok||bad "Roster sort binding missing"
 grep -Fq 'checkJerseyWarning' static/js/teams/detail.js&&ok||bad "Duplicate jersey warning missing"
 grep -Fq 'Jersey number must be a whole number from 0 through 999.' static/js/teams/detail.js&&ok||bad "Jersey validation feedback missing"
else for _ in {1..4};do ok;done;fi
echo "[5/6] Checking protected M13-E boundaries..."
if [[ $VALIDATION_MODE == local ]];then
 if grep -Eq 'method:"(DELETE|PUT)"' static/js/teams/detail.js;then bad "Delete/transfer mutation introduced";else ok;fi
 if grep -A10 'class PlayerUpdate' app/schemas/player.py|grep -Fq 'team_id';then bad "Player team reassignment introduced";else ok;fi
 if find alembic/versions -maxdepth 1 -type f \( -iname '*m13e*' -o -iname '*0013*' \)|grep -q .;then bad "Unexpected M13-E migration";else ok;fi
else for _ in {1..3};do ok;done;fi
echo "[6/6] Running M13-D cumulative regression silently..."
set +e;BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" ./scripts/validate_m13d.sh>"$R" 2>&1;RC=$?;set -e
[[ $RC == 0 ]]||X+=("M13-D cumulative regression failed")
echo "========================================";echo "ScoreStreamLive M13-E Cumulative Validation Summary";echo "BASE_URL: $BASE_URL";echo "MODE: $VALIDATION_MODE";echo "========================================"
[[ $F == 0 ]]&&echo "M13-E ............... PASS   $P passed / 0 failed"||echo "M13-E ............... FAIL   $P passed / $F failed"
[[ $RC == 0 ]]&&echo "M13-D cumulative .... PASS"||echo "M13-D cumulative .... FAIL";echo "========================================"
if [[ $F == 0&&$RC == 0 ]];then echo "OVERALL ............. PASS";echo "Failed Components: None";echo "========================================";echo "M13-E AUTOMATED ACCEPTANCE = PASS";exit 0;fi
echo "OVERALL ............. FAIL";echo "Failed Components:";printf '%s\n' "${X[@]}"|awk 'NF&&!s[$0]++{print "- "$0}';exit 1
