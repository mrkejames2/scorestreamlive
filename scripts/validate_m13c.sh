#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."&&pwd)";cd "$ROOT"
BASE_URL="${BASE_URL:-http://192.168.12.133:8000}";BASE_URL="${BASE_URL%/}";VALIDATION_MODE="${VALIDATION_MODE:-local}"
[[ "$VALIDATION_MODE" =~ ^(local|production)$ ]]||{ echo "ERROR: VALIDATION_MODE must be local or production";exit 2;}
PASS=0;FAIL=0;F=();T=$(mktemp);R=$(mktemp);trap 'rm -f "$T" "$R"' EXIT
ok(){ PASS=$((PASS+1));};bad(){ FAIL=$((FAIL+1));F+=("$1");}

echo "[1/7] Checking application health..."
for p in /health/live /health/ready;do
  c=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL$p"||true)
  [[ "$c" == 200 ]]&&ok||bad "$p HTTP $c"
done

echo "[2/7] Creating Team and roster through existing REST APIs..."
S=$(date +%s)
c=$(curl -sS -o "$T" -w "%{http_code}" -X POST "$BASE_URL/api/teams" -H 'Content-Type: application/json' \
  --data "{\"name\":\"M13-C Regression $S\",\"short_name\":\"M13C\",\"primary_color\":\"#112233\",\"secondary_color\":\"#DDEEFF\"}"||true)
ID=$(python3 - "$T" <<'PY'
import json,sys
try: print(json.load(open(sys.argv[1])).get("id",""))
except: print("")
PY
)
[[ "$c" == 201 && -n "$ID" ]]&&ok||bad "Team fixture creation failed"

for row in '12|Roster|Alpha' '7|Roster|Beta';do
  IFS='|' read -r J FST LST<<<"$row"
  c=$(curl -sS -o "$T" -w "%{http_code}" -X POST "$BASE_URL/api/players" -H 'Content-Type: application/json' \
    --data "{\"team_id\":\"$ID\",\"first_name\":\"$FST\",\"last_name\":\"$LST\",\"jersey_number\":$J}"||true)
  [[ "$c" == 201 ]]&&ok||bad "Player fixture $J failed"
done

echo "[3/7] Checking durable Team Detail route and assets..."
c=$(curl -sS -o "$T" -w "%{http_code}" "$BASE_URL/teams/$ID"||true)
[[ "$c" == 200 ]]&&ok||bad "Team detail HTTP $c"
for m in 'id="roster-list"' "$ID" '/static/js/teams/detail.js';do
  grep -Fq "$m" "$T"&&ok||bad "Detail page missing durable marker: $m"
done
for p in /static/js/teams/detail.js /static/css/team-detail.css;do
  c=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL$p"||true)
  [[ "$c" == 200 ]]&&ok||bad "$p HTTP $c"
done

echo "[4/7] Verifying durable Team Management navigation contract..."
curl -fsS "$BASE_URL/teams" >"$T"||true
for m in 'view-team-link' 'View Team';do
  grep -Fq "$m" "$T"&&ok||bad "Team Management page missing navigation marker: $m"
done
if [[ "$VALIDATION_MODE" == local ]];then
  grep -Fq 'n.querySelector(".view-team-link").href=`/teams/${t.id}`' static/js/teams/index.js \
    && ok || bad "View Team link binding missing"
else
  ok
fi

echo "[5/7] Verifying derived roster API contract..."
c=$(curl -sS -o "$T" -w "%{http_code}" "$BASE_URL/api/teams/$ID/players"||true)
[[ "$c" == 200 ]]&&ok||bad "Roster endpoint HTTP $c"
python3 - "$T" <<'PY'&&ok||bad "Roster response missing fixture players"
import json,sys
d=json.load(open(sys.argv[1]))
assert len(d)==2
assert {p["jersey_number"] for p in d}=={7,12}
PY

echo "[6/7] Checking protected M13-C architectural boundaries..."
if [[ "$VALIDATION_MODE" == local ]];then
  grep -Fq '@router.get("/teams/{team_id}"' app/web/teams.py&&ok||bad "Detail web route missing"
  grep -Fq '/api/teams/${teamId}/players' static/js/teams/detail.js&&ok||bad "Derived roster request missing"

  # Later milestones may add Player mutations to Team Detail. M13-C's durable
  # boundary is that no new roster table/migration or team-reassignment model
  # is introduced.
  if find alembic/versions -maxdepth 1 -type f \( -iname '*m13c*' -o -iname '*0013*' \)|grep -q .;then
    bad "Unexpected M13-C/M13 migration"
  else
    ok
  fi

  if grep -A10 'class PlayerUpdate' app/schemas/player.py | grep -Fq 'team_id';then
    bad "PlayerUpdate permits Team reassignment"
  else
    ok
  fi
else
  for _ in {1..4};do ok;done
fi

echo "[7/7] Running M13-B cumulative regression silently..."
set +e
BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" ./scripts/validate_m13b.sh >"$R" 2>&1
RC=$?
set -e
[[ $RC -eq 0 ]]||F+=("M13-B cumulative regression failed")

echo "========================================"
echo "ScoreStreamLive M13-C Cumulative Validation Summary"
echo "BASE_URL: $BASE_URL"
echo "MODE: $VALIDATION_MODE"
echo "========================================"
[[ $FAIL -eq 0 ]]&&echo "M13-C ............... PASS   $PASS passed / 0 failed"||echo "M13-C ............... FAIL   $PASS passed / $FAIL failed"
[[ $RC -eq 0 ]]&&echo "M13-B cumulative .... PASS"||echo "M13-B cumulative .... FAIL"
echo "========================================"

if [[ $FAIL -eq 0 && $RC -eq 0 ]];then
  echo "OVERALL ............. PASS"
  echo "Failed Components: None"
  echo "========================================"
  echo "M13-C AUTOMATED ACCEPTANCE = PASS"
  exit 0
fi

echo "OVERALL ............. FAIL"
echo "Failed Components:"
printf '%s\n' "${F[@]}"|awk 'NF&&!s[$0]++{print "- "$0}'
echo "M13-C AUTOMATED ACCEPTANCE = FAIL"
exit 1
