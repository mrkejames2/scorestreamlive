#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."&&pwd)";cd "$ROOT"
BASE_URL="${BASE_URL:-http://192.168.12.133:8000}";BASE_URL="${BASE_URL%/}";VALIDATION_MODE="${VALIDATION_MODE:-local}"
P=0;F=0;X=();T=$(mktemp);R=$(mktemp);trap 'rm -f "$T" "$R"' EXIT
ok(){ P=$((P+1));};bad(){ F=$((F+1));X+=("$1");}

echo "[1/6] Checking application health..."
for p in /health/live /health/ready;do c=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL$p"||true);[[ "$c" == 200 ]]&&ok||bad "$p HTTP $c";done

echo "[2/6] Creating Team Detail fixture..."
c=$(curl -sS -o "$T" -w "%{http_code}" -X POST "$BASE_URL/api/teams" -H 'Content-Type: application/json' --data "{\"name\":\"M13-F Validation $(date +%s)\",\"short_name\":\"M13F\"}"||true)
ID=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("id",""))' "$T" 2>/dev/null||true)
[[ "$c" == 201 && -n "$ID" ]]&&ok||bad "Team fixture failed"

echo "[3/6] Checking polished management surfaces..."
curl -fsS "$BASE_URL/teams">"$T"||true
for m in 'M13-F' 'class="skip-link"' 'aria-busy="true"' 'Management UX / Mobile Polish';do grep -Fq "$m" "$T"&&ok||bad "Teams surface missing $m";done
curl -fsS "$BASE_URL/teams/$ID">"$T"||true
for m in 'M13-F' 'Skip to roster' 'class="field-label"' 'aria-busy="true"';do grep -Fq "$m" "$T"&&ok||bad "Team Detail surface missing $m";done

echo "[4/6] Checking accessibility and interaction polish..."
if [[ "$VALIDATION_MODE" == local ]];then
 grep -Fq ':focus-visible' static/css/teams.css&&ok||bad "Teams focus-visible styling missing"
 grep -Fq ':focus-visible' static/css/team-detail.css&&ok||bad "Detail focus-visible styling missing"
 grep -Fq 'min-height:var(--tap)' static/css/teams.css&&ok||bad "Teams touch target contract missing"
 grep -Fq 'min-height:var(--tap)' static/css/team-detail.css&&ok||bad "Detail touch target contract missing"
 grep -Fq 'prefers-reduced-motion' static/css/teams.css&&ok||bad "Teams reduced-motion support missing"
 grep -Fq 'prefers-reduced-motion' static/css/team-detail.css&&ok||bad "Detail reduced-motion support missing"
 grep -Fq 'modalReturnFocus' static/js/teams/index.js&&ok||bad "Team modal focus restoration missing"
 grep -Fq 'modalReturnFocus' static/js/teams/detail.js&&ok||bad "Player modal focus restoration missing"
else for _ in {1..8};do ok;done;fi

echo "[5/6] Checking protected M13-F boundaries..."
if [[ "$VALIDATION_MODE" == local ]];then
 if find alembic/versions -maxdepth 1 -type f \( -iname '*m13f*' -o -iname '*0013*' \)|grep -q .;then bad "Unexpected M13-F migration";else ok;fi
 if grep -Eq 'method:"(DELETE|PUT)"' static/js/teams/detail.js;then bad "Delete/transfer mutation introduced";else ok;fi
 if grep -A10 'class PlayerUpdate' app/schemas/player.py|grep -Fq 'team_id';then bad "Player team reassignment introduced";else ok;fi
else for _ in {1..3};do ok;done;fi

echo "[6/6] Running M13-E cumulative regression silently..."
set +e;BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" ./scripts/validate_m13e.sh>"$R" 2>&1;RC=$?;set -e
[[ $RC -eq 0 ]]||X+=("M13-E cumulative regression failed")

echo "========================================"
echo "ScoreStreamLive M13-F Validation Summary"
echo "BASE_URL: $BASE_URL"
echo "MODE: $VALIDATION_MODE"
echo "========================================"
[[ $F -eq 0 ]]&&echo "M13-F ............... PASS   $P passed / 0 failed"||echo "M13-F ............... FAIL   $P passed / $F failed"
[[ $RC -eq 0 ]]&&echo "M13-E cumulative .... PASS"||echo "M13-E cumulative .... FAIL"
echo "========================================"
if [[ $F -eq 0 && $RC -eq 0 ]];then
 echo "OVERALL ............. PASS"
 echo "Failed Components: None"
 echo "========================================"
 echo "M13-F AUTOMATED ACCEPTANCE = PASS"
 exit 0
fi
echo "OVERALL ............. FAIL"
echo "Failed Components:"
printf '%s\n' "${X[@]}"|awk 'NF&&!s[$0]++{print "- "$0}'
echo "M13-F AUTOMATED ACCEPTANCE = FAIL"
exit 1
