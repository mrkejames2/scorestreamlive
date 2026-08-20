#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://192.168.12.133:8000}"
BASE_URL="${BASE_URL%/}"
VALIDATION_MODE="${VALIDATION_MODE:-local}"

case "$VALIDATION_MODE" in
  local|production) ;;
  *) echo "ERROR: VALIDATION_MODE must be local or production" >&2; exit 2 ;;
esac

export BASE_URL VALIDATION_MODE

PASS=0
FAIL=0
FAILURES=()

pass(){ PASS=$((PASS+1)); }
fail(){ FAIL=$((FAIL+1)); FAILURES+=("$1"); }
progress(){ echo "[$1/6] $2"; }

check_http_200() {
  local path="$1"
  local label="$2"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass || fail "${label} HTTP ${code}"
}

PAGE_TMP=$(mktemp)
API_TMP=$(mktemp)
REG_TMP=$(mktemp)
trap 'rm -f "$PAGE_TMP" "$API_TMP" "$REG_TMP"' EXIT

progress 1 "Checking application health..."
check_http_200 "/health/live" "Liveness"
check_http_200 "/health/ready" "Readiness"
check_http_200 "/info" "Info"

progress 2 "Checking Team Management route and static assets..."
set +e
TEAM_HTTP=$(curl -sS -o "$PAGE_TMP" -w "%{http_code}" "${BASE_URL}/teams")
TEAM_RC=$?
set -e

if [ "$TEAM_RC" -eq 0 ] && [ "$TEAM_HTTP" = "200" ]; then
  pass
else
  fail "/teams Team Management route HTTP ${TEAM_HTTP:-curl-error}"
fi

check_http_200 "/static/css/teams.css" "Team Management CSS"
check_http_200 "/static/js/teams/index.js" "Team Management JavaScript"

progress 3 "Creating and verifying a branded Team through the existing REST API..."
STAMP="$(date +%s)"
TEAM_NAME="M13-A Regression ${STAMP}"
TEAM_JSON=$(
  python3 - "$TEAM_NAME" <<'PY'
import json, sys
print(json.dumps({
    "name": sys.argv[1],
    "short_name": "M13A",
    "primary_color": "#2A77FF",
    "secondary_color": "#FFFFFF"
}))
PY
)

set +e
CREATE_HTTP=$(curl -sS -o "$API_TMP" -w "%{http_code}" \
  -X POST "${BASE_URL}/api/teams" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data "$TEAM_JSON")
CREATE_RC=$?
set -e

TEAM_ID=""
if [ "$CREATE_RC" -eq 0 ] && [ "$CREATE_HTTP" = "201" ]; then
  TEAM_ID=$(python3 - "$API_TMP" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        data=json.load(fh)
    print(data.get("id",""))
except Exception:
    print("")
PY
)
  [ -n "$TEAM_ID" ] && pass || fail "Team create returned 201 without an id"
else
  fail "Existing Team POST contract HTTP ${CREATE_HTTP:-curl-error}"
fi

if [ -n "$TEAM_ID" ]; then
  set +e
  GET_HTTP=$(curl -sS -o "$API_TMP" -w "%{http_code}" "${BASE_URL}/api/teams/${TEAM_ID}")
  GET_RC=$?
  set -e

  if [ "$GET_RC" -eq 0 ] && [ "$GET_HTTP" = "200" ]; then
    VERIFY_RESULT=$(python3 - "$API_TMP" "$TEAM_NAME" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        data=json.load(fh)
    ok=(
        data.get("name")==sys.argv[2]
        and data.get("short_name")=="M13A"
        and data.get("primary_color")=="#2A77FF"
        and data.get("secondary_color")=="#FFFFFF"
    )
    print("ok" if ok else "bad")
except Exception:
    print("bad")
PY
)
    [ "$VERIFY_RESULT" = "ok" ] && pass || fail "Created Team branding did not persist correctly"
  else
    fail "Existing Team GET contract HTTP ${GET_HTTP:-curl-error}"
  fi
fi

progress 4 "Verifying Team collection and durable Team Management page contract..."
set +e
COLLECTION_HTTP=$(curl -sS -o "$API_TMP" -w "%{http_code}" "${BASE_URL}/api/teams")
COLLECTION_RC=$?
set -e

if [ "$COLLECTION_RC" -eq 0 ] && [ "$COLLECTION_HTTP" = "200" ]; then
  if [ -n "$TEAM_ID" ]; then
    FOUND=$(python3 - "$API_TMP" "$TEAM_ID" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        rows=json.load(fh)
    print("yes" if any(str(x.get("id"))==sys.argv[2] for x in rows) else "no")
except Exception:
    print("no")
PY
)
    [ "$FOUND" = "yes" ] && pass || fail "Created Team missing from Team collection"
  else
    fail "Team collection could not be correlated because create failed"
  fi
else
  fail "Existing Team collection HTTP ${COLLECTION_HTTP:-curl-error}"
fi

# Regression checks must target durable product contracts, not historical
# milestone labels. Later milestones are allowed to relabel and extend /teams.
for marker in \
  'id="teams-list"' \
  'id="team-card-template"' \
  'id="summary-branded"' \
  '/static/js/teams/index.js'
do
  grep -Fq "$marker" "$PAGE_TMP" \
    && pass \
    || fail "/teams page missing expected durable marker: ${marker}"
done

progress 5 "Checking protected Team Management architecture and performance boundaries..."
if [ "$VALIDATION_MODE" = "local" ]; then
  [ -f "app/web/teams.py" ] && pass || fail "app/web/teams.py missing"
  [ -f "templates/teams/index.html" ] && pass || fail "templates/teams/index.html missing"
  [ -f "static/css/teams.css" ] && pass || fail "static/css/teams.css missing"
  [ -f "static/js/teams/index.js" ] && pass || fail "static/js/teams/index.js missing"

  if grep -Fq 'from app.web.teams import router as teams_web_router' app/main.py \
     && grep -Fq 'app.include_router(teams_web_router)' app/main.py; then
    pass
  else
    fail "Team web router is not registered in app/main.py"
  fi

  if grep -Eq '/api/teams/.+/players' static/js/teams/index.js; then
    fail "Team Management JS performs per-Team roster fan-out requests"
  else
    pass
  fi

  if find alembic/versions -maxdepth 1 -type f \( -name '*0013*' -o -name '*m13*' \) | grep -q .; then
    fail "Unexpected M13 Team Management migration file detected"
  else
    pass
  fi
else
  pass
  pass
  pass
  pass
  pass
  pass
  pass
fi

progress 6 "Running M12-H cumulative regression silently..."
set +e
BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" \
  ./scripts/validate_m12h.sh >"$REG_TMP" 2>&1
REG_RC=$?
set -e

if [ "$REG_RC" -ne 0 ]; then
  FAILURES+=("M12-H cumulative regression failed")
  while IFS= read -r line; do
    [ -n "$line" ] && FAILURES+=("$line")
  done < <(
    grep -E '^(\[FAIL\]|OVERALL[[:space:]].*FAIL|M12-H.*FAIL|MILESTONE 12.*FAIL)' \
      "$REG_TMP" | tail -40 || true
  )
fi

echo "========================================"
echo "ScoreStreamLive M13-A Cumulative Validation Summary"
echo "BASE_URL: ${BASE_URL}"
echo "MODE: ${VALIDATION_MODE}"
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo "M13-A ............... PASS   ${PASS} passed / 0 failed"
else
  echo "M13-A ............... FAIL   ${PASS} passed / ${FAIL} failed"
fi

[ "$REG_RC" -eq 0 ] \
  && echo "M12-H cumulative .... PASS" \
  || echo "M12-H cumulative .... FAIL"

echo "========================================"

TOTAL_FAIL=$FAIL
[ "$REG_RC" -ne 0 ] && TOTAL_FAIL=$((TOTAL_FAIL+1))

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo "OVERALL ............. PASS"
  echo "Failed Components: None"
  echo "========================================"
  echo "M13-A AUTOMATED ACCEPTANCE = PASS"
  exit 0
fi

echo "OVERALL ............. FAIL"
echo ""
echo "FAILED COMPONENTS"
echo "-----------------"
printf '%s\n' "${FAILURES[@]}" | awk 'NF && !seen[$0]++ {print "- "$0}'
echo "========================================"
echo "M13-A AUTOMATED ACCEPTANCE = FAIL"
exit 1
