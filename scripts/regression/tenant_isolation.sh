#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

source scripts/lib/validation.sh
validation_init || exit $?

fail=0
TMP_DIR=""
APP_CONTAINER=""

pass_check() { echo "PASS $1"; }
fail_check() { echo "FAIL $1"; fail=1; }

curl_code() {
  curl --connect-timeout 5 --max-time 15 -sS "$@" || true
}

json_has_id() {
  python3 - "$1" "$2" <<'PY'
import json, sys
path, expected = sys.argv[1], sys.argv[2]
try:
    with open(path) as handle:
        data = json.load(handle)
except Exception:
    raise SystemExit(1)
if not isinstance(data, list):
    raise SystemExit(1)
raise SystemExit(
    0 if any(
        isinstance(item, dict) and str(item.get("id")) == expected
        for item in data
    ) else 1
)
PY
}

json_lacks_id() {
  ! json_has_id "$1" "$2"
}

container_exec() {
  timeout --foreground -k 5s "$1" docker exec "$APP_CONTAINER" "${@:2}"
}

cleanup() {
  if [[ "$VALIDATION_MODE" == "local" && -n "${APP_CONTAINER:-}" ]]; then
    timeout --foreground -k 5s 20s docker exec "$APP_CONTAINER" \
      python -m app.cli.m15e_release_fixture cleanup \
      >/dev/null 2>&1 || true
  fi
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

if [[ "$VALIDATION_MODE" != "local" ]]; then
  grep -Fq 'async def visible_team_ids(' app/auth/authorization.py \
    && pass_check "production structural Team isolation guard present" \
    || fail_check "production structural Team isolation guard missing"
  grep -Fq 'async def visible_game_ids(' app/auth/authorization.py \
    && pass_check "production structural Game isolation guard present" \
    || fail_check "production structural Game isolation guard missing"
  grep -Fq 'def _same_club(' app/auth/authorization.py \
    && pass_check "production same-Club guard present" \
    || fail_check "production same-Club guard missing"
  exit "$fail"
fi

command -v docker >/dev/null 2>&1 || {
  echo "FAIL docker command unavailable"
  exit 1
}
command -v timeout >/dev/null 2>&1 || {
  echo "FAIL timeout command unavailable"
  exit 1
}

echo "INFO resolving running app container"
APP_CONTAINER="$(timeout 10s docker compose ps -q app 2>/dev/null | head -1)"
if [[ -z "$APP_CONTAINER" ]]; then
  echo "FAIL could not resolve running app container"
  exit 1
fi

if ! timeout 10s docker inspect -f '{{.State.Running}}' "$APP_CONTAINER" 2>/dev/null \
  | grep -Fxq true
then
  echo "FAIL app container is not running"
  exit 1
fi
pass_check "running app container resolved"

TMP_DIR="$(mktemp -d)"
SETUP_LOG="$TMP_DIR/setup.log"

echo "INFO creating disposable M15-E tenant fixtures"
if ! container_exec 30s \
  python -m app.cli.m15e_release_fixture setup \
  >"$SETUP_LOG" 2>&1
then
  rc=$?
  echo "FAIL M15-E fixture setup did not complete successfully (rc=${rc})"
  echo "----- fixture setup output -----"
  tail -40 "$SETUP_LOG" 2>/dev/null || true
  echo "--------------------------------"
  exit 1
fi

fixture_json="$(
python3 - "$SETUP_LOG" <<'PY'
import json, sys
candidate = None
with open(sys.argv[1], errors="replace") as handle:
    for raw in handle:
        line = raw.strip()
        if not line.startswith("{"):
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and "director_a_email" in value:
            candidate = value
if candidate is None:
    raise SystemExit(1)
print(json.dumps(candidate))
PY
)" || {
  echo "FAIL could not locate fixture JSON in setup output"
  echo "----- fixture setup output -----"
  tail -40 "$SETUP_LOG" 2>/dev/null || true
  echo "--------------------------------"
  exit 1
}

printf '%s\n' "$fixture_json" >"$TMP_DIR/fixture.json"

eval "$(
python3 - "$TMP_DIR/fixture.json" <<'PY'
import json, shlex, sys
with open(sys.argv[1]) as handle:
    data = json.load(handle)
for key, value in data.items():
    print(f"M15E_{key.upper()}={shlex.quote(str(value))}")
PY
)"

pass_check "disposable tenant fixtures created"

login() {
  local email="$1" jar="$2" output="$3"
  curl_code \
    -c "$jar" \
    -o "$output" \
    -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${email}\",\"password\":\"${M15E_PASSWORD}\"}" \
    "${BASE_URL}/api/auth/login"
}

code="$(curl_code -o "$TMP_DIR/invalid.json" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d '{"email":"nobody@example.invalid","password":"wrong"}' \
  "${BASE_URL}/api/auth/login")"
[[ "$code" == "401" ]] \
  && pass_check "invalid login rejected" \
  || fail_check "invalid login expected 401 got $code"

code="$(login "$M15E_DISABLED_A_EMAIL" "$TMP_DIR/disabled.jar" "$TMP_DIR/disabled.json")"
[[ "$code" == "401" ]] \
  && pass_check "disabled user login rejected" \
  || fail_check "disabled login expected 401 got $code"

code="$(login "$M15E_DIRECTOR_A_EMAIL" "$TMP_DIR/director-a.jar" "$TMP_DIR/director-a-login.json")"
[[ "$code" == "200" ]] \
  && pass_check "Director A login" \
  || fail_check "Director A login expected 200 got $code"

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o "$TMP_DIR/a-teams.json" -w '%{http_code}' "${BASE_URL}/api/teams")"
if [[ "$code" == "200" ]] \
  && json_has_id "$TMP_DIR/a-teams.json" "$M15E_TEAM_A1_ID" \
  && json_lacks_id "$TMP_DIR/a-teams.json" "$M15E_TEAM_B1_ID"
then
  pass_check "Director A Team collection isolated"
else
  fail_check "Director A Team collection isolation"
fi

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o "$TMP_DIR/a-games.json" -w '%{http_code}' "${BASE_URL}/api/games")"
if [[ "$code" == "200" ]] \
  && json_has_id "$TMP_DIR/a-games.json" "$M15E_GAME_A_MANAGED_ID" \
  && json_lacks_id "$TMP_DIR/a-games.json" "$M15E_GAME_B_ID"
then
  pass_check "Director A Game collection isolated"
else
  fail_check "Director A Game collection isolation"
fi

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o /dev/null -w '%{http_code}' "${BASE_URL}/api/teams/${M15E_TEAM_B1_ID}")"
[[ "$code" == "404" ]] \
  && pass_check "cross-Club Team direct ID hidden" \
  || fail_check "cross-Club Team expected 404 got $code"

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o /dev/null -w '%{http_code}' "${BASE_URL}/api/games/${M15E_GAME_B_ID}")"
[[ "$code" == "404" ]] \
  && pass_check "cross-Club Game direct ID hidden" \
  || fail_check "cross-Club Game expected 404 got $code"

code="$(login "$M15E_MANAGER_A_EMAIL" "$TMP_DIR/manager.jar" "$TMP_DIR/manager-login.json")"
[[ "$code" == "200" ]] \
  && pass_check "Manager login" \
  || fail_check "Manager login expected 200 got $code"

code="$(curl_code -b "$TMP_DIR/manager.jar" -o "$TMP_DIR/m-teams.json" -w '%{http_code}' "${BASE_URL}/api/teams")"
if [[ "$code" == "200" ]] \
  && json_has_id "$TMP_DIR/m-teams.json" "$M15E_TEAM_A1_ID" \
  && json_lacks_id "$TMP_DIR/m-teams.json" "$M15E_TEAM_A2_ID"
then
  pass_check "Manager sees assigned Team only"
else
  fail_check "Manager Team visibility"
fi

code="$(curl_code -b "$TMP_DIR/manager.jar" -o "$TMP_DIR/m-games.json" -w '%{http_code}' "${BASE_URL}/api/games")"
if [[ "$code" == "200" ]] \
  && json_has_id "$TMP_DIR/m-games.json" "$M15E_GAME_A_MANAGED_ID" \
  && json_lacks_id "$TMP_DIR/m-games.json" "$M15E_GAME_A_UNASSIGNED_ID"
then
  pass_check "Manager Game visibility follows assigned Team"
else
  fail_check "Manager Game visibility"
fi

code="$(curl_code -b "$TMP_DIR/manager.jar" -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"M15E forbidden manager game\",\"home_team_id\":\"${M15E_TEAM_A1_ID}\",\"away_team_id\":\"${M15E_TEAM_A2_ID}\"}" \
  "${BASE_URL}/api/games")"
[[ "$code" == "403" ]] \
  && pass_check "Manager cannot create Game with unassigned Team" \
  || fail_check "Manager create guard expected 403 got $code"

code="$(login "$M15E_OPERATOR_A_EMAIL" "$TMP_DIR/operator.jar" "$TMP_DIR/operator-login.json")"
[[ "$code" == "200" ]] \
  && pass_check "Operator login" \
  || fail_check "Operator login expected 200 got $code"

code="$(curl_code -b "$TMP_DIR/operator.jar" -o "$TMP_DIR/o-games.json" -w '%{http_code}' "${BASE_URL}/api/games")"
if [[ "$code" == "200" ]] \
  && json_has_id "$TMP_DIR/o-games.json" "$M15E_GAME_A_MANAGED_ID" \
  && json_lacks_id "$TMP_DIR/o-games.json" "$M15E_GAME_A_UNASSIGNED_ID"
then
  pass_check "Operator sees explicitly assigned Game only"
else
  fail_check "Operator Game visibility"
fi

code="$(curl_code -b "$TMP_DIR/operator.jar" -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d '{"name":"M15E forbidden operator team"}' \
  "${BASE_URL}/api/teams")"
[[ "$code" == "403" ]] \
  && pass_check "Operator cannot create Team" \
  || fail_check "Operator Team create expected 403 got $code"

code="$(curl_code -b "$TMP_DIR/operator.jar" -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d '{"name":"M15E forbidden operator game"}' \
  "${BASE_URL}/api/games")"
[[ "$code" == "403" ]] \
  && pass_check "Operator cannot create Game" \
  || fail_check "Operator Game create expected 403 got $code"

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o /dev/null -w '%{http_code}' "${BASE_URL}/api/auth/me")"
[[ "$code" == "200" ]] \
  && pass_check "session survives normal navigation" \
  || fail_check "session persistence expected 200 got $code"

code="$(curl_code -b "$TMP_DIR/director-a.jar" -c "$TMP_DIR/director-a.jar" -o /dev/null -w '%{http_code}' -X POST "${BASE_URL}/api/auth/logout")"
[[ "$code" == "204" ]] \
  && pass_check "logout accepted" \
  || fail_check "logout expected 204 got $code"

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o /dev/null -w '%{http_code}' "${BASE_URL}/api/auth/me")"
[[ "$code" == "401" ]] \
  && pass_check "logout invalidates session" \
  || fail_check "post-logout /me expected 401 got $code"

code="$(curl_code -o /dev/null -w '%{http_code}' "${BASE_URL}/api/public/games/${M15E_GAME_A_MANAGED_ID}/overlay-state")"
[[ "$code" == "200" ]] \
  && pass_check "public Overlay state remains public" \
  || fail_check "public Overlay state expected 200 got $code"

exit "$fail"
