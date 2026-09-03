#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

source scripts/lib/validation.sh
validation_init || exit $?

fail=0
TMP_DIR=""
APP_CONTAINER=""

pass_check(){ echo "PASS $1"; }
fail_check(){ echo "FAIL $1"; fail=1; }

curl_code(){
  curl --connect-timeout 5 --max-time 15 -sS "$@" || true
}

container_exec(){
  timeout --foreground -k 5s "$1" docker exec "$APP_CONTAINER" "${@:2}"
}

cleanup(){
  if [[ "$VALIDATION_MODE" == "local" && -n "${APP_CONTAINER:-}" ]]; then
    timeout --foreground -k 5s 20s docker exec "$APP_CONTAINER" \
      python -m app.cli.m15e_release_fixture cleanup >/dev/null 2>&1 || true
  fi
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

structural_checks(){
  grep -Fq '@router.patch("/members/{user_id}")' app/api/club_admin.py \
    && pass_check "member lifecycle PATCH route present" \
    || fail_check "member lifecycle PATCH route missing"

  grep -Fq 'Club must retain at least one active Director' app/services/access_admin_service.py \
    && pass_check "last active Director invariant present" \
    || fail_check "last active Director invariant missing"

  grep -Fq 'delete(UserSession).where(UserSession.user_id == user.id)' app/services/access_admin_service.py \
    && pass_check "deactivation session revocation present" \
    || fail_check "deactivation session revocation missing"

  grep -Fq 'delete(TeamManager).where(TeamManager.user_id == user.id)' app/services/access_admin_service.py \
    && pass_check "role transition TeamManager cleanup present" \
    || fail_check "role transition TeamManager cleanup missing"

  grep -Fq 'delete(GameOperator).where(GameOperator.user_id == user.id)' app/services/access_admin_service.py \
    && pass_check "role transition GameOperator cleanup present" \
    || fail_check "role transition GameOperator cleanup missing"

  grep -Fq 'not user.is_active' app/services/access_admin_service.py \
    && pass_check "inactive users excluded from new assignments" \
    || fail_check "inactive assignment guard missing"
}

structural_checks

if [[ "$VALIDATION_MODE" != "local" ]]; then
  code="$(curl_code -o /dev/null -w '%{http_code}' "${BASE_URL}/api/admin/members")"
  [[ "$code" == "401" ]] \
    && pass_check "production logged-out Club user administration denied" \
    || fail_check "production logged-out members expected 401 got $code"
  exit "$fail"
fi

command -v docker >/dev/null 2>&1 || { echo "FAIL docker command unavailable"; exit 1; }
command -v timeout >/dev/null 2>&1 || { echo "FAIL timeout command unavailable"; exit 1; }

APP_CONTAINER="$(timeout 10s docker compose ps -q app 2>/dev/null | head -1)"
[[ -n "$APP_CONTAINER" ]] || { echo "FAIL could not resolve running app container"; exit 1; }
timeout 10s docker inspect -f '{{.State.Running}}' "$APP_CONTAINER" 2>/dev/null | grep -Fxq true \
  || { echo "FAIL app container is not running"; exit 1; }
pass_check "running app container resolved"

TMP_DIR="$(mktemp -d)"
SETUP_LOG="$TMP_DIR/setup.log"

if ! container_exec 30s python -m app.cli.m15e_release_fixture setup >"$SETUP_LOG" 2>&1; then
  echo "FAIL M15-E fixture setup failed"
  tail -40 "$SETUP_LOG" || true
  exit 1
fi

fixture_json="$(
python3 - "$SETUP_LOG" <<'PY'
import json, sys
candidate = None
for raw in open(sys.argv[1], errors="replace"):
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
)" || { echo "FAIL fixture JSON missing"; exit 1; }

printf '%s\n' "$fixture_json" >"$TMP_DIR/fixture.json"
eval "$(
python3 - "$TMP_DIR/fixture.json" <<'PY'
import json, shlex, sys
data=json.load(open(sys.argv[1]))
for key,value in data.items():
    print(f"M17A_{key.upper()}={shlex.quote(str(value))}")
PY
)"

login(){
  local email="$1" jar="$2" output="$3"
  curl_code -c "$jar" -o "$output" -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${email}\",\"password\":\"${M17A_PASSWORD}\"}" \
    "${BASE_URL}/api/auth/login"
}

json_member_id(){
  python3 - "$1" "$2" <<'PY'
import json,sys
items=json.load(open(sys.argv[1]))
email=sys.argv[2]
for item in items:
    if item.get("email")==email:
        print(item["id"])
        raise SystemExit(0)
raise SystemExit(1)
PY
}

json_assignment_absent(){
  python3 - "$1" "$2" "$3" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
section,user_id=sys.argv[2],sys.argv[3]
raise SystemExit(0 if all(x.get("user_id") != user_id for x in data.get(section,[])) else 1)
PY
}

code="$(login "$M17A_DIRECTOR_A_EMAIL" "$TMP_DIR/director-a.jar" "$TMP_DIR/director-a-login.json")"
[[ "$code" == "200" ]] && pass_check "Director A login" || fail_check "Director A login expected 200 got $code"

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o "$TMP_DIR/members-a.json" -w '%{http_code}' "${BASE_URL}/api/admin/members")"
[[ "$code" == "200" ]] && pass_check "Director lists Club members" || fail_check "Director members expected 200 got $code"

DIRECTOR_A_ID="$(json_member_id "$TMP_DIR/members-a.json" "$M17A_DIRECTOR_A_EMAIL")" || { echo "FAIL Director A ID missing"; exit 1; }
MANAGER_A_ID="$(json_member_id "$TMP_DIR/members-a.json" "$M17A_MANAGER_A_EMAIL")" || { echo "FAIL Manager A ID missing"; exit 1; }
OPERATOR_A_ID="$(json_member_id "$TMP_DIR/members-a.json" "$M17A_OPERATOR_A_EMAIL")" || { echo "FAIL Operator A ID missing"; exit 1; }
DISABLED_A_ID="$(json_member_id "$TMP_DIR/members-a.json" "$M17A_DISABLED_A_EMAIL")" || { echo "FAIL Disabled A ID missing"; exit 1; }

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o /dev/null -w '%{http_code}' "${BASE_URL}/api/admin/members/${MANAGER_A_ID}")"
[[ "$code" == "200" ]] && pass_check "Director inspects same-Club member" || fail_check "same-Club member expected 200 got $code"

code="$(curl_code -o /dev/null -w '%{http_code}' "${BASE_URL}/api/admin/members")"
[[ "$code" == "401" ]] && pass_check "unauthenticated administration denied" || fail_check "unauthenticated members expected 401 got $code"

code="$(login "$M17A_MANAGER_A_EMAIL" "$TMP_DIR/manager.jar" "$TMP_DIR/manager-login.json")"
[[ "$code" == "200" ]] || fail_check "Manager login expected 200 got $code"
code="$(curl_code -b "$TMP_DIR/manager.jar" -o /dev/null -w '%{http_code}' "${BASE_URL}/api/admin/members")"
[[ "$code" == "403" ]] && pass_check "Manager administration denied" || fail_check "Manager admin expected 403 got $code"

code="$(login "$M17A_OPERATOR_A_EMAIL" "$TMP_DIR/operator.jar" "$TMP_DIR/operator-login.json")"
[[ "$code" == "200" ]] || fail_check "Operator login expected 200 got $code"
code="$(curl_code -b "$TMP_DIR/operator.jar" -o /dev/null -w '%{http_code}' "${BASE_URL}/api/admin/members")"
[[ "$code" == "403" ]] && pass_check "Operator administration denied" || fail_check "Operator admin expected 403 got $code"

code="$(login "$M17A_DIRECTOR_B_EMAIL" "$TMP_DIR/director-b.jar" "$TMP_DIR/director-b-login.json")"
[[ "$code" == "200" ]] || fail_check "Director B login expected 200 got $code"
code="$(curl_code -b "$TMP_DIR/director-b.jar" -o "$TMP_DIR/members-b.json" -w '%{http_code}' "${BASE_URL}/api/admin/members")"
[[ "$code" == "200" ]] || fail_check "Director B members expected 200 got $code"
DIRECTOR_B_ID="$(json_member_id "$TMP_DIR/members-b.json" "$M17A_DIRECTOR_B_EMAIL")" || { echo "FAIL Director B ID missing"; exit 1; }

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o /dev/null -w '%{http_code}' "${BASE_URL}/api/admin/members/${DIRECTOR_B_ID}")"
[[ "$code" == "404" ]] && pass_check "cross-Club member direct ID hidden" || fail_check "cross-Club GET expected 404 got $code"

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o /dev/null -w '%{http_code}' -X PATCH \
  -H 'Content-Type: application/json' -d '{"role":"MANAGER"}' \
  "${BASE_URL}/api/admin/members/${DIRECTOR_B_ID}")"
[[ "$code" == "404" ]] && pass_check "cross-Club member mutation hidden" || fail_check "cross-Club PATCH expected 404 got $code"

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o /dev/null -w '%{http_code}' -X PATCH \
  -H 'Content-Type: application/json' -d '{"role":"MANAGER"}' \
  "${BASE_URL}/api/admin/members/${DIRECTOR_A_ID}")"
[[ "$code" == "409" ]] && pass_check "last active Director demotion blocked" || fail_check "last Director demotion expected 409 got $code"

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o /dev/null -w '%{http_code}' -X PATCH \
  -H 'Content-Type: application/json' -d '{"is_active":false}' \
  "${BASE_URL}/api/admin/members/${DIRECTOR_A_ID}")"
[[ "$code" == "409" ]] && pass_check "last active Director deactivation blocked" || fail_check "last Director deactivate expected 409 got $code"

code="$(curl_code -b "$TMP_DIR/director-a.jar" -o "$TMP_DIR/promote.json" -w '%{http_code}' -X PATCH \
  -H 'Content-Type: application/json' -d '{"role":"DIRECTOR"}' \
  "${BASE_URL}/api/admin/members/${MANAGER_A_ID}")"
[[ "$code" == "200" ]] && pass_check "Director promotion allowed" || fail_check "Director promotion expected 200 got $code"

curl_code -b "$TMP_DIR/director-a.jar" -o "$TMP_DIR/assign-after-promote.json" -w '%{http_code}' \
  "${BASE_URL}/api/admin/assignments" >/dev/null
json_assignment_absent "$TMP_DIR/assign-after-promote.json" team_managers "$MANAGER_A_ID" \
  && pass_check "Director promotion removes TeamManager assignment" \
  || fail_check "Director promotion left TeamManager assignment"

code="$(login "$M17A_MANAGER_A_EMAIL" "$TMP_DIR/new-director.jar" "$TMP_DIR/new-director-login.json")"
[[ "$code" == "200" ]] && pass_check "promoted Director can login" || fail_check "promoted Director login expected 200 got $code"

code="$(curl_code -b "$TMP_DIR/new-director.jar" -o /dev/null -w '%{http_code}' -X PATCH \
  -H 'Content-Type: application/json' -d '{"role":"MANAGER"}' \
  "${BASE_URL}/api/admin/members/${DIRECTOR_A_ID}")"
[[ "$code" == "200" ]] && pass_check "Director demotion allowed when another active Director exists" || fail_check "safe Director demotion expected 200 got $code"

code="$(curl_code -b "$TMP_DIR/new-director.jar" -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' -d "{\"user_id\":\"${DIRECTOR_A_ID}\"}" \
  "${BASE_URL}/api/admin/teams/${M17A_TEAM_A2_ID}/managers")"
[[ "$code" == "201" ]] && pass_check "Manager assignment created" || fail_check "Manager assignment expected 201 got $code"

code="$(curl_code -b "$TMP_DIR/new-director.jar" -o /dev/null -w '%{http_code}' -X PATCH \
  -H 'Content-Type: application/json' -d '{"role":"OPERATOR"}' \
  "${BASE_URL}/api/admin/members/${DIRECTOR_A_ID}")"
[[ "$code" == "200" ]] && pass_check "Manager to Operator role change allowed" || fail_check "Manager to Operator expected 200 got $code"

curl_code -b "$TMP_DIR/new-director.jar" -o "$TMP_DIR/assign-after-manager-change.json" -w '%{http_code}' \
  "${BASE_URL}/api/admin/assignments" >/dev/null
json_assignment_absent "$TMP_DIR/assign-after-manager-change.json" team_managers "$DIRECTOR_A_ID" \
  && pass_check "Manager to Operator removes TeamManager assignment" \
  || fail_check "Manager to Operator left TeamManager assignment"

code="$(curl_code -b "$TMP_DIR/new-director.jar" -o /dev/null -w '%{http_code}' -X PATCH \
  -H 'Content-Type: application/json' -d '{"role":"MANAGER"}' \
  "${BASE_URL}/api/admin/members/${OPERATOR_A_ID}")"
[[ "$code" == "200" ]] && pass_check "Operator to Manager role change allowed" || fail_check "Operator to Manager expected 200 got $code"

curl_code -b "$TMP_DIR/new-director.jar" -o "$TMP_DIR/assign-after-operator-change.json" -w '%{http_code}' \
  "${BASE_URL}/api/admin/assignments" >/dev/null
json_assignment_absent "$TMP_DIR/assign-after-operator-change.json" game_operators "$OPERATOR_A_ID" \
  && pass_check "Operator to Manager removes GameOperator assignment" \
  || fail_check "Operator to Manager left GameOperator assignment"

code="$(login "$M17A_OPERATOR_A_EMAIL" "$TMP_DIR/lifecycle-user.jar" "$TMP_DIR/lifecycle-login.json")"
[[ "$code" == "200" ]] && pass_check "lifecycle target login" || fail_check "lifecycle target login expected 200 got $code"

code="$(curl_code -b "$TMP_DIR/new-director.jar" -o /dev/null -w '%{http_code}' -X PATCH \
  -H 'Content-Type: application/json' -d '{"is_active":false}' \
  "${BASE_URL}/api/admin/members/${OPERATOR_A_ID}")"
[[ "$code" == "200" ]] && pass_check "member deactivation allowed" || fail_check "member deactivation expected 200 got $code"

code="$(curl_code -b "$TMP_DIR/lifecycle-user.jar" -o /dev/null -w '%{http_code}' "${BASE_URL}/api/auth/me")"
[[ "$code" == "401" ]] && pass_check "deactivation revokes existing authenticated session" || fail_check "inactive session expected 401 got $code"

code="$(curl_code -b "$TMP_DIR/new-director.jar" -o /dev/null -w '%{http_code}' -X PATCH \
  -H 'Content-Type: application/json' -d '{"is_active":true}' \
  "${BASE_URL}/api/admin/members/${OPERATOR_A_ID}")"
[[ "$code" == "200" ]] && pass_check "member reactivation allowed" || fail_check "member reactivation expected 200 got $code"

code="$(curl_code -b "$TMP_DIR/new-director.jar" -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' -d "{\"user_id\":\"${DISABLED_A_ID}\"}" \
  "${BASE_URL}/api/admin/games/${M17A_GAME_A_UNASSIGNED_ID}/operators")"
[[ "$code" == "422" ]] && pass_check "inactive Operator cannot receive new assignment" || fail_check "inactive Operator assignment expected 422 got $code"

code="$(curl_code -o /dev/null -w '%{http_code}' "${BASE_URL}/api/public/games/${M17A_GAME_A_MANAGED_ID}/overlay-state")"
[[ "$code" == "200" ]] && pass_check "public Overlay remains accessible" || fail_check "public Overlay expected 200 got $code"

exit "$fail"
