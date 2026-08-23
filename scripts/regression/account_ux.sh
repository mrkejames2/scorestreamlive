#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

source scripts/lib/validation.sh
validation_init || exit $?

fail=0

check() {
  local description="$1"
  local pattern="$2"
  local file="$3"

  if grep -Fq "$pattern" "$file"; then
    echo "PASS $description"
  else
    echo "FAIL $description"
    fail=1
  fi
}

if [[ "$VALIDATION_MODE" == "local" ]]; then
  check "Account route" \
    '@router.get("/account"' \
    app/web/account.py

  check "Member API" \
    '@router.get("/members")' \
    app/api/club_admin.py

  check "Manager assignment API" \
    '@router.post("/teams/{team_id}/managers"' \
    app/api/club_admin.py

  check "Operator assignment API" \
    '@router.post("/games/{game_id}/operators"' \
    app/api/club_admin.py

  check "Role-filtered Games" \
    'visible_game_ids(db, current_user)' \
    app/api/games.py

  check "Role-filtered Teams" \
    'visible_team_ids(' \
    app/api/teams.py

  check "Manager Game creation guard" \
    'can_create_game_with_teams(' \
    app/api/games.py

  check "Manager Team assignment guard" \
    'managed_team_ids = await visible_team_ids(db, user)' \
    app/auth/authorization.py

  check "Visible Logout" \
    'logout.textContent = "Logout"' \
    static/js/account-nav.js

  check "Logout POST action" \
    'fetch("/logout", { method: "POST" })' \
    static/js/account-nav.js
fi

for path in /account /api/admin/members; do
  code="$(
    curl -sS \
      -o /dev/null \
      -w '%{http_code}' \
      "${BASE_URL}${path}" \
      || true
  )"

  if [[ "$code" == "401" ]]; then
    echo "PASS logged-out ${path} -> 401"
  else
    echo "FAIL logged-out ${path} expected 401 got ${code}"
    fail=1
  fi
done

exit "$fail"
