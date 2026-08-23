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
  check "Account management shell" 'class="account-shell"' templates/account/index.html
  check "Account Games-style header" 'class="account-header"' templates/account/index.html
  check "Account management panel" 'class="account-panel"' templates/account/index.html
  check "Account summary cards" 'class="summary-grid"' templates/account/index.html
  check "Account dark management theme" 'linear-gradient(180deg,#0a1422,#07101d 52%,#050b14)' static/css/account.css
  check "Global nav has Games" 'games.textContent = "Games"' static/js/account-nav.js
  check "Global nav has Teams" 'teams.textContent = "Teams"' static/js/account-nav.js
  check "Global nav has Account" 'account.href = "/account"' static/js/account-nav.js
  check "Global nav has Logout" 'logout.textContent = "Logout"' static/js/account-nav.js
  check "Logout uses POST" 'fetch("/logout", { method: "POST" })' static/js/account-nav.js

  for template in \
    templates/games/index.html \
    templates/games/detail.html \
    templates/games/setup.html \
    templates/teams/index.html \
    templates/teams/detail.html \
    templates/control/game.html
  do
    check "Nav JS in ${template}" '/static/js/account-nav.js' "$template"
    check "Nav CSS in ${template}" '/static/css/account-nav.css' "$template"
  done
fi

exit "$fail"
