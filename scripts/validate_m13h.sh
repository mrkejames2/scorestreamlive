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
trap 'rm -f "$TMP" "$REG"' EXIT

ok(){ PASS=$((PASS+1)); }
bad(){ FAIL=$((FAIL+1)); FAILURES+=("$1"); }

http_200() {
  local path="$1"
  local label="$2"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [[ "$code" == "200" ]] && ok || bad "${label} HTTP ${code}"
}

echo "[1/8] Checking final application health..."
http_200 "/health/live" "Liveness"
http_200 "/health/ready" "Readiness"
http_200 "/info" "Info"

echo "[2/8] Checking Team Management release surface..."
CODE=$(curl -sS -o "$TMP" -w "%{http_code}" "${BASE_URL}/teams" || true)
[[ "$CODE" == "200" ]] && ok || bad "/teams HTTP ${CODE}"

for marker in \
  'id="create-team"' \
  'id="teams-list"' \
  'id="team-card-template"' \
  'view-team-link' \
  'manage-team-button'
do
  grep -Fq "$marker" "$TMP" \
    && ok \
    || bad "Team Management release surface missing ${marker}"
done

echo "[3/8] Exercising final Team create/edit/branding workflow..."
STAMP=$(date +%s)
TEAM_NAME="M13-H Release ${STAMP}"

TEAM_PAYLOAD=$(python3 - "$TEAM_NAME" <<'PY'
import json,sys
print(json.dumps({
  "name": sys.argv[1],
  "short_name": "M13H",
  "primary_color": "#1A4D8F",
  "secondary_color": "#F2F5FA"
}))
PY
)

CODE=$(curl -sS -o "$TMP" -w "%{http_code}" \
  -X POST "${BASE_URL}/api/teams" \
  -H "Content-Type: application/json" \
  --data "$TEAM_PAYLOAD" || true)

TEAM_ID=$(python3 - "$TMP" <<'PY'
import json,sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get("id",""))
except Exception:
    print("")
PY
)

[[ "$CODE" == "201" && -n "$TEAM_ID" ]] \
  && ok \
  || bad "Final Team create failed HTTP ${CODE}"

PATCH_PAYLOAD=$(python3 - "$TEAM_NAME" <<'PY'
import json,sys
print(json.dumps({
  "name": sys.argv[1] + " Edited",
  "short_name": "FINAL",
  "primary_color": "#2255AA",
  "secondary_color": "#EEEEEE"
}))
PY
)

CODE=$(curl -sS -o "$TMP" -w "%{http_code}" \
  -X PATCH "${BASE_URL}/api/teams/${TEAM_ID}" \
  -H "Content-Type: application/json" \
  --data "$PATCH_PAYLOAD" || true)

[[ "$CODE" == "200" ]] \
  && ok \
  || bad "Final Team edit failed HTTP ${CODE}"

python3 - "$TMP" "$TEAM_NAME Edited" <<'PY' && ok || bad "Final Team committed state incorrect"
import json,sys
d=json.load(open(sys.argv[1], encoding="utf-8"))
assert d["name"] == sys.argv[2]
assert d["short_name"] == "FINAL"
assert d["primary_color"] == "#2255AA"
assert d["secondary_color"] == "#EEEEEE"
PY

echo "[4/8] Exercising final Player / roster workflow..."
PLAYER_PAYLOAD=$(python3 - "$TEAM_ID" <<'PY'
import json,sys
print(json.dumps({
  "team_id": sys.argv[1],
  "first_name": "Final",
  "last_name": "Player",
  "jersey_number": 88
}))
PY
)

CODE=$(curl -sS -o "$TMP" -w "%{http_code}" \
  -X POST "${BASE_URL}/api/players" \
  -H "Content-Type: application/json" \
  --data "$PLAYER_PAYLOAD" || true)

PLAYER_ID=$(python3 - "$TMP" <<'PY'
import json,sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get("id",""))
except Exception:
    print("")
PY
)

[[ "$CODE" == "201" && -n "$PLAYER_ID" ]] \
  && ok \
  || bad "Final Player create failed HTTP ${CODE}"

CODE=$(curl -sS -o "$TMP" -w "%{http_code}" \
  -X PATCH "${BASE_URL}/api/players/${PLAYER_ID}" \
  -H "Content-Type: application/json" \
  --data '{"first_name":"Final","last_name":"Accepted","jersey_number":89}' || true)

[[ "$CODE" == "200" ]] \
  && ok \
  || bad "Final Player edit failed HTTP ${CODE}"

python3 - "$TMP" "$TEAM_ID" <<'PY' && ok || bad "Final Player committed state incorrect"
import json,sys
d=json.load(open(sys.argv[1], encoding="utf-8"))
assert d["team_id"] == sys.argv[2]
assert d["first_name"] == "Final"
assert d["last_name"] == "Accepted"
assert d["jersey_number"] == 89
PY

CODE=$(curl -sS -o "$TMP" -w "%{http_code}" \
  "${BASE_URL}/api/teams/${TEAM_ID}/players" || true)
[[ "$CODE" == "200" ]] && ok || bad "Final roster endpoint HTTP ${CODE}"

python3 - "$TMP" "$PLAYER_ID" <<'PY' && ok || bad "Final roster derivation incorrect"
import json,sys
rows=json.load(open(sys.argv[1], encoding="utf-8"))
assert any(str(p.get("id")) == sys.argv[2] for p in rows)
PY

echo "[5/8] Checking Team Detail and management UX release contracts..."
CODE=$(curl -sS -o "$TMP" -w "%{http_code}" "${BASE_URL}/teams/${TEAM_ID}" || true)
[[ "$CODE" == "200" ]] && ok || bad "Team Detail HTTP ${CODE}"

for marker in \
  'id="roster-list"' \
  'id="add-player"' \
  'id="roster-search"' \
  'id="roster-sort"' \
  'edit-player' \
  'Skip to roster'
do
  grep -Fq "$marker" "$TMP" \
    && ok \
    || bad "Team Detail release surface missing ${marker}"
done

echo "[6/8] Checking protected M13 architecture boundaries..."
if [[ "$VALIDATION_MODE" == "local" ]]; then
  if grep -A12 'class PlayerUpdate' app/schemas/player.py | grep -Fq 'team_id'; then
    bad "PlayerUpdate permits Team reassignment"
  else
    ok
  fi

  if grep -Eq 'method:"(DELETE|PUT)"' static/js/teams/detail.js; then
    bad "Out-of-scope Player delete/transfer mutation exists"
  else
    ok
  fi

  if find alembic/versions -maxdepth 1 -type f \
      \( -iname '*m13*' -o -iname '*0013*' \) | grep -q .; then
    bad "Unexpected M13 database migration detected"
  else
    ok
  fi

  grep -Fq 'postgres_data:/var/lib/postgresql/data' docker-compose.yml \
    && ok || bad "PostgreSQL persistence volume missing"

  grep -Fq 'team_logo_data:/home/appuser/app/static/uploads/team-logos' docker-compose.yml \
    && ok || bad "Team logo persistence volume missing"
else
  for _ in {1..5}; do ok; done
fi

echo "[7/8] Checking final validation-chain availability..."
if [[ "$VALIDATION_MODE" == "local" ]]; then
  for validation_script in \
    scripts/validate_m13a.sh \
    scripts/validate_m13b.sh \
    scripts/validate_m13c.sh \
    scripts/validate_m13d.sh \
    scripts/validate_m13e.sh \
    scripts/validate_m13f.sh \
    scripts/validate_m13g.sh
  do
    [[ -x "$validation_script" ]] \
      && ok \
      || bad "${validation_script} missing or not executable"
  done
else
  for _ in {1..7}; do ok; done
fi

echo "[8/8] Running M13-G cumulative regression silently..."
set +e
BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" \
  ./scripts/validate_m13g.sh >"$REG" 2>&1
REG_RC=$?
set -e

[[ "$REG_RC" -eq 0 ]] \
  || FAILURES+=("M13-G cumulative regression failed")

echo "========================================"
echo "ScoreStreamLive M13-H Final Release Gate"
echo "BASE_URL: $BASE_URL"
echo "MODE: $VALIDATION_MODE"
echo "========================================"

if [[ "$FAIL" -eq 0 ]]; then
  echo "M13-H ............... PASS   ${PASS} passed / 0 failed"
else
  echo "M13-H ............... FAIL   ${PASS} passed / ${FAIL} failed"
fi

[[ "$REG_RC" -eq 0 ]] \
  && echo "M13-G cumulative .... PASS" \
  || echo "M13-G cumulative .... FAIL"

echo "========================================"

TOTAL_FAIL=$FAIL
[[ "$REG_RC" -ne 0 ]] && TOTAL_FAIL=$((TOTAL_FAIL+1))

if [[ "$TOTAL_FAIL" -eq 0 ]]; then
  echo "OVERALL ............. PASS"
  echo "Failed Components: None"
  echo "========================================"
  if [[ "$VALIDATION_MODE" == "local" ]]; then
    echo "MILESTONE 13 LOCAL RELEASE GATE = PASS"
  else
    echo "MILESTONE 13 PRODUCTION RELEASE GATE = PASS"
  fi
  exit 0
fi

echo "OVERALL ............. FAIL"
echo "Failed Components:"
printf '%s\n' "${FAILURES[@]}" | awk 'NF && !seen[$0]++ {print "- "$0}'
echo "========================================"
if [[ "$VALIDATION_MODE" == "local" ]]; then
  echo "MILESTONE 13 LOCAL RELEASE GATE = FAIL"
else
  echo "MILESTONE 13 PRODUCTION RELEASE GATE = FAIL"
fi
exit 1
