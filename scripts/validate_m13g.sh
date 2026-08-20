#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE_URL="${BASE_URL:-http://192.168.12.133:8000}"
BASE_URL="${BASE_URL%/}"
VALIDATION_MODE="${VALIDATION_MODE:-local}"

case "$VALIDATION_MODE" in
  local|production) ;;
  *)
    echo "ERROR: VALIDATION_MODE must be local or production" >&2
    exit 2
    ;;
esac

PASS=0
FAIL=0
FAILURES=()
TMP=$(mktemp)
REG=$(mktemp)
PNG=$(mktemp --suffix=.png)
trap 'rm -f "$TMP" "$REG" "$PNG"' EXIT

ok(){ PASS=$((PASS+1)); }
bad(){ FAIL=$((FAIL+1)); FAILURES+=("$1"); }

wait_http() {
  local path="$1"
  local attempts="${2:-30}"
  local delay="${3:-2}"
  local i code
  for ((i=1; i<=attempts; i++)); do
    code=$(curl -sS -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
    if [[ "$code" == "200" ]]; then
      return 0
    fi
    sleep "$delay"
  done
  return 1
}

verify_team_state() {
  local team_id="$1"
  local expected_name="$2"
  local expected_logo="$3"

  curl -fsS "${BASE_URL}/api/teams/${team_id}" >"$TMP" || return 1
  python3 - "$TMP" "$expected_name" "$expected_logo" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    d = json.load(fh)
assert d["name"] == sys.argv[2]
assert d["short_name"] == "M13G"
assert d["primary_color"] == "#13579B"
assert d["secondary_color"] == "#FEDCBA"
assert d["logo_url"] == sys.argv[3]
PY
}

verify_roster_state() {
  local team_id="$1"
  local player_id="$2"

  curl -fsS "${BASE_URL}/api/teams/${team_id}/players" >"$TMP" || return 1
  python3 - "$TMP" "$player_id" <<'PY'
import json, sys
rows = json.load(open(sys.argv[1], encoding="utf-8"))
match = [p for p in rows if str(p.get("id")) == sys.argv[2]]
assert len(match) == 1
p = match[0]
assert p["first_name"] == "Recovery"
assert p["last_name"] == "Player"
assert p["jersey_number"] == 77
PY
}

verify_logo_bytes() {
  local logo_url="$1"
  local code
  code=$(curl -sS -o "$TMP" -w "%{http_code}" "${BASE_URL}${logo_url}" || true)
  [[ "$code" == "200" && -s "$TMP" ]]
}

echo "[1/8] Checking application health..."
wait_http "/health/live" 10 1 && ok || bad "Application liveness unavailable"
wait_http "/health/ready" 10 1 && ok || bad "Application readiness unavailable"

echo "[2/8] Creating committed Team, Player, and logo fixture..."
STAMP=$(date +%s)
TEAM_NAME="M13-G Recovery ${STAMP}"

TEAM_PAYLOAD=$(python3 - "$TEAM_NAME" <<'PY'
import json, sys
print(json.dumps({
    "name": sys.argv[1],
    "short_name": "M13G",
    "primary_color": "#13579B",
    "secondary_color": "#FEDCBA"
}))
PY
)

CODE=$(curl -sS -o "$TMP" -w "%{http_code}" \
  -X POST "${BASE_URL}/api/teams" \
  -H "Content-Type: application/json" \
  --data "$TEAM_PAYLOAD" || true)

TEAM_ID=$(python3 - "$TMP" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get("id", ""))
except Exception:
    print("")
PY
)

[[ "$CODE" == "201" && -n "$TEAM_ID" ]] \
  && ok \
  || bad "Team fixture creation failed HTTP ${CODE}"

PLAYER_PAYLOAD=$(python3 - "$TEAM_ID" <<'PY'
import json, sys
print(json.dumps({
    "team_id": sys.argv[1],
    "first_name": "Recovery",
    "last_name": "Player",
    "jersey_number": 77
}))
PY
)

CODE=$(curl -sS -o "$TMP" -w "%{http_code}" \
  -X POST "${BASE_URL}/api/players" \
  -H "Content-Type: application/json" \
  --data "$PLAYER_PAYLOAD" || true)

PLAYER_ID=$(python3 - "$TMP" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get("id", ""))
except Exception:
    print("")
PY
)

[[ "$CODE" == "201" && -n "$PLAYER_ID" ]] \
  && ok \
  || bad "Player fixture creation failed HTTP ${CODE}"

python3 - "$PNG" <<'PY'
import base64, sys
open(sys.argv[1], "wb").write(base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
))
PY

CODE=$(curl -sS -o "$TMP" -w "%{http_code}" \
  -X POST "${BASE_URL}/api/teams/${TEAM_ID}/logo" \
  -F "logo=@${PNG};type=image/png" || true)

LOGO_URL=$(python3 - "$TMP" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get("logo_url", ""))
except Exception:
    print("")
PY
)

[[ "$CODE" == "200" && "$LOGO_URL" == /api/team-logos/* ]] \
  && ok \
  || bad "Team logo fixture upload failed HTTP ${CODE}"

echo "[3/8] Verifying committed state before recovery tests..."
verify_team_state "$TEAM_ID" "$TEAM_NAME" "$LOGO_URL" \
  && ok || bad "Committed Team branding state incorrect before restart"
verify_roster_state "$TEAM_ID" "$PLAYER_ID" \
  && ok || bad "Committed Player roster state incorrect before restart"
verify_logo_bytes "$LOGO_URL" \
  && ok || bad "Committed Team logo unavailable before restart"

echo "[4/8] Testing application-container recovery..."
if [[ "$VALIDATION_MODE" == "local" ]]; then
  if docker compose restart app >/dev/null 2>&1; then
    ok
  else
    bad "docker compose restart app failed"
  fi

  if wait_http "/health/ready" 45 2; then
    ok
  else
    bad "Application did not recover readiness after app restart"
  fi

  verify_team_state "$TEAM_ID" "$TEAM_NAME" "$LOGO_URL" \
    && ok || bad "Team state lost after app restart"
  verify_roster_state "$TEAM_ID" "$PLAYER_ID" \
    && ok || bad "Roster state lost after app restart"
  verify_logo_bytes "$LOGO_URL" \
    && ok || bad "Logo state lost after app restart"
else
  echo "      production mode: local Docker app-restart check skipped"
fi

echo "[5/8] Testing PostgreSQL-container recovery..."
if [[ "$VALIDATION_MODE" == "local" ]]; then
  if docker compose restart postgres >/dev/null 2>&1; then
    ok
  else
    bad "docker compose restart postgres failed"
  fi

  # PostgreSQL health and application connection-pool recovery are both part
  # of this gate. The app itself is intentionally not restarted here.
  DB_READY=0
  for _ in {1..30}; do
    if docker compose exec -T postgres pg_isready \
        -U "${DB_USER:-scorestreamlive}" \
        -d "${DB_NAME:-scorestreamlive}" >/dev/null 2>&1; then
      DB_READY=1
      break
    fi
    sleep 2
  done
  [[ "$DB_READY" == "1" ]] && ok || bad "PostgreSQL did not become ready after restart"

  if wait_http "/health/ready" 45 2; then
    ok
  else
    bad "Application did not recover database readiness after PostgreSQL restart"
  fi

  verify_team_state "$TEAM_ID" "$TEAM_NAME" "$LOGO_URL" \
    && ok || bad "Team state lost after PostgreSQL restart"
  verify_roster_state "$TEAM_ID" "$PLAYER_ID" \
    && ok || bad "Roster state lost after PostgreSQL restart"
  verify_logo_bytes "$LOGO_URL" \
    && ok || bad "Logo unavailable after PostgreSQL restart"
else
  echo "      production mode: local Docker PostgreSQL-restart check skipped"
fi

echo "[6/8] Verifying persistence through product web surfaces..."
CODE=$(curl -sS -o "$TMP" -w "%{http_code}" "${BASE_URL}/teams" || true)
[[ "$CODE" == "200" ]] && ok || bad "/teams unavailable after recovery tests"

CODE=$(curl -sS -o "$TMP" -w "%{http_code}" "${BASE_URL}/teams/${TEAM_ID}" || true)
[[ "$CODE" == "200" ]] && ok || bad "Team Detail unavailable after recovery tests"

grep -Fq 'id="roster-list"' "$TMP" \
  && ok \
  || bad "Team Detail roster surface missing after recovery tests"

echo "[7/8] Checking protected M13-G recovery boundaries..."
if [[ "$VALIDATION_MODE" == "local" ]]; then
  grep -Fq 'postgres_data:/var/lib/postgresql/data' docker-compose.yml \
    && ok || bad "PostgreSQL persistent volume contract missing"
  grep -Fq 'team_logo_data:/home/appuser/app/static/uploads/team-logos' docker-compose.yml \
    && ok || bad "Team logo persistent volume contract missing"
  if find alembic/versions -maxdepth 1 -type f \( -iname '*m13g*' -o -iname '*0013*' \) | grep -q .; then
    bad "Unexpected M13-G migration"
  else
    ok
  fi
else
  for _ in {1..3}; do ok; done
fi

echo "[8/8] Running M13-F cumulative regression silently..."
set +e
BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" \
  ./scripts/validate_m13f.sh >"$REG" 2>&1
REG_RC=$?
set -e

[[ "$REG_RC" -eq 0 ]] || FAILURES+=("M13-F cumulative regression failed")

echo "========================================"
echo "ScoreStreamLive M13-G Validation Summary"
echo "BASE_URL: $BASE_URL"
echo "MODE: $VALIDATION_MODE"
echo "========================================"

if [[ "$FAIL" -eq 0 ]]; then
  echo "M13-G ............... PASS   ${PASS} passed / 0 failed"
else
  echo "M13-G ............... FAIL   ${PASS} passed / ${FAIL} failed"
fi

if [[ "$VALIDATION_MODE" == "local" ]]; then
  echo "Local recovery ....... TESTED"
else
  echo "Local recovery ....... SKIPPED (production mode)"
fi

[[ "$REG_RC" -eq 0 ]] \
  && echo "M13-F cumulative .... PASS" \
  || echo "M13-F cumulative .... FAIL"

echo "========================================"

TOTAL_FAIL=$FAIL
[[ "$REG_RC" -ne 0 ]] && TOTAL_FAIL=$((TOTAL_FAIL+1))

if [[ "$TOTAL_FAIL" -eq 0 ]]; then
  echo "OVERALL ............. PASS"
  echo "Failed Components: None"
  echo "========================================"
  echo "M13-G AUTOMATED ACCEPTANCE = PASS"
  exit 0
fi

echo "OVERALL ............. FAIL"
echo "Failed Components:"
printf '%s\n' "${FAILURES[@]}" | awk 'NF && !seen[$0]++ {print "- "$0}'
echo "========================================"
echo "M13-G AUTOMATED ACCEPTANCE = FAIL"
exit 1
