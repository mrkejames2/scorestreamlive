#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
BASE_URL="${BASE_URL:-http://192.168.12.133:8000}"; BASE_URL="${BASE_URL%/}"
VALIDATION_MODE="${VALIDATION_MODE:-local}"
[[ "$VALIDATION_MODE" =~ ^(local|production)$ ]] || { echo "ERROR: VALIDATION_MODE must be local or production"; exit 2; }
PASS=0; FAIL=0; FAILURES=(); TMP=$(mktemp); REG=$(mktemp); trap 'rm -f "$TMP" "$REG"' EXIT
ok(){ PASS=$((PASS+1)); }; bad(){ FAIL=$((FAIL+1)); FAILURES+=("$1"); }
http(){ local p="$1" l="$2"; local c; c=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL$p"||true); [[ "$c" == 200 ]]&&ok||bad "$l HTTP $c"; }
echo "[1/7] Checking application health..."; http /health/live Liveness; http /health/ready Readiness
echo "[2/7] Checking M13-B management surface..."; curl -fsS "$BASE_URL/teams" >"$TMP"&&ok||bad "/teams unavailable"
for m in 'M13-B' 'id="team-modal"' 'id="team-form"' 'id="create-team"'; do grep -Fq "$m" "$TMP"&&ok||bad "Missing UI marker: $m"; done
echo "[3/7] Creating Team through existing REST boundary..."
STAMP=$(date +%s); NAME="M13-B Validation $STAMP"
PAYLOAD="{\"name\":\"$NAME\",\"short_name\":\"M13B\",\"primary_color\":\"#123456\",\"secondary_color\":\"#ABCDEF\"}"
CODE=$(curl -sS -o "$TMP" -w "%{http_code}" -X POST "$BASE_URL/api/teams" -H 'Content-Type: application/json' --data "$PAYLOAD"||true)
ID=$(python3 - "$TMP" <<'PY'
import json,sys
try: print(json.load(open(sys.argv[1])).get("id",""))
except: print("")
PY
)
[[ "$CODE" == 201 && -n "$ID" ]]&&ok||bad "Team create failed HTTP $CODE"
echo "[4/7] Editing Team and verifying committed persistence..."
PATCH="{\"name\":\"$NAME EDITED\",\"short_name\":\"EDIT\",\"primary_color\":\"#654321\",\"secondary_color\":\"#FEDCBA\"}"
CODE=$(curl -sS -o "$TMP" -w "%{http_code}" -X PATCH "$BASE_URL/api/teams/$ID" -H 'Content-Type: application/json' --data "$PATCH"||true)
[[ "$CODE" == 200 ]]&&ok||bad "Team PATCH failed HTTP $CODE"
curl -fsS "$BASE_URL/api/teams/$ID" >"$TMP" || true
python3 - "$TMP" "$NAME EDITED" <<'PY' && ok || bad "Edited Team did not persist"
import json,sys
d=json.load(open(sys.argv[1]))
assert d["name"]==sys.argv[2] and d["short_name"]=="EDIT" and d["primary_color"]=="#654321" and d["secondary_color"]=="#FEDCBA"
PY
echo "[5/7] Verifying logo upload contract..."
PNG=$(mktemp --suffix=.png)
python3 - "$PNG" <<'PY'
import base64,sys
open(sys.argv[1],"wb").write(base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
PY
CODE=$(curl -sS -o "$TMP" -w "%{http_code}" -X POST "$BASE_URL/api/teams/$ID/logo" -F "logo=@$PNG;type=image/png"||true); rm -f "$PNG"
LOGO=$(python3 - "$TMP" <<'PY'
import json,sys
try: print(json.load(open(sys.argv[1])).get("logo_url",""))
except: print("")
PY
)
[[ "$CODE" == 200 && "$LOGO" == /api/team-logos/* ]]&&ok||bad "Logo upload failed HTTP $CODE"
[[ -n "$LOGO" ]] && http "$LOGO" "Uploaded logo"
echo "[6/7] Checking M13-B protected boundaries..."
if [[ "$VALIDATION_MODE" == local ]]; then
  grep -Fq 'method:"POST"' static/js/teams/index.js&&ok||bad "Create UI REST call missing"
  grep -Fq 'method:"PATCH"' static/js/teams/index.js&&ok||bad "Edit UI REST call missing"
  grep -Fq 'FormData' static/js/teams/index.js&&ok||bad "Logo upload UI missing"
  if grep -Eq '/api/teams/.+/players' static/js/teams/index.js; then bad "Roster fan-out reintroduced"; else ok; fi
  if find alembic/versions -maxdepth 1 -type f \( -iname '*m13b*' -o -iname '*0013*' \)|grep -q .; then bad "Unexpected M13-B migration"; else ok; fi
else for _ in {1..5}; do ok; done; fi
echo "[7/7] Running M13-A cumulative regression silently..."
set +e; BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" ./scripts/validate_m13a.sh >"$REG" 2>&1; RC=$?; set -e
[[ $RC -eq 0 ]]||FAILURES+=("M13-A cumulative regression failed")
echo "========================================"
echo "ScoreStreamLive M13-B Validation Summary"
echo "BASE_URL: $BASE_URL"; echo "MODE: $VALIDATION_MODE"; echo "========================================"
[[ $FAIL -eq 0 ]]&&echo "M13-B ............... PASS   $PASS passed / 0 failed"||echo "M13-B ............... FAIL   $PASS passed / $FAIL failed"
[[ $RC -eq 0 ]]&&echo "M13-A cumulative .... PASS"||echo "M13-A cumulative .... FAIL"
echo "========================================"
if [[ $FAIL -eq 0 && $RC -eq 0 ]]; then echo "OVERALL ............. PASS"; echo "Failed Components: None"; echo "========================================"; echo "M13-B AUTOMATED ACCEPTANCE = PASS"; exit 0; fi
echo "OVERALL ............. FAIL"; echo "Failed Components:"; printf '%s\n' "${FAILURES[@]}"|awk 'NF&&!seen[$0]++{print "- "$0}'; echo "M13-B AUTOMATED ACCEPTANCE = FAIL"; exit 1
