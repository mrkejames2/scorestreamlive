#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source scripts/lib/validation.sh
validation_init || exit $?
fail=0

check() {
  local description="$1" pattern="$2" file="$3"
  if grep -Fq "$pattern" "$file"; then
    echo "PASS $description"
  else
    echo "FAIL $description"
    fail=1
  fi
}

if [[ "$VALIDATION_MODE" == "local" ]]; then
  check "Account link explicit" 'account.href = "/account"' static/js/account-nav.js
  check "Director Club Admin label" '? "Club Admin" : "Account"' static/js/account-nav.js
  check "Identity separated from Account link" 'identity.className = "ssl-nav-identity"' static/js/account-nav.js
  check "Account CTA visually emphasized" '.ssl-account-nav .ssl-nav-account' static/css/account-nav.css
  check "Logout still visible" 'logout.textContent = "Logout"' static/js/account-nav.js
  check "Logout still POSTs" 'fetch("/logout", { method: "POST" })' static/js/account-nav.js
fi

exit "$fail"
