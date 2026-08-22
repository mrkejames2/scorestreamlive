#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source scripts/lib/validation.sh
validation_init || exit $?
fail=0

check(){
  local d="$1" p="$2" f="$3"
  if grep -Fq "$p" "$f"; then
    echo "PASS $d"
  else
    echo "FAIL $d"
    fail=1
  fi
}

if [[ "$VALIDATION_MODE" == "local" ]]; then
  check "User model" 'class User(Base):' app/models/user.py
  check "UserSession model" 'class UserSession(Base):' app/models/user_session.py
  check "Argon2 hashing" 'PasswordHasher()' app/services/auth_service.py
  check "opaque token" 'secrets.token_urlsafe(48)' app/services/auth_service.py
  check "token hash" 'hashlib.sha256' app/services/auth_service.py
  check "HttpOnly cookie" 'httponly=True' app/services/auth_service.py
  check "current user dependency" 'async def require_current_user(' app/auth/dependencies.py
  check "bootstrap command" 'async def bootstrap()' app/cli/bootstrap_user.py
  check "migration users" 'op.create_table(' alembic/versions/20260824_0010_create_users_and_sessions.py
fi

curl -fsS "${BASE_URL}/login" | grep -Fq 'Sign in' || {
  echo "FAIL login page"
  fail=1
}

me_status="$(curl -sS -o /dev/null -w '%{http_code}' "${BASE_URL}/api/auth/me" || true)"
if [[ "$me_status" == "401" ]]; then
  echo "PASS unauthenticated /api/auth/me rejected"
else
  echo "FAIL unauthenticated /api/auth/me expected 401 got ${me_status}"
  fail=1
fi

curl -fsS "${BASE_URL}/games" >/dev/null || {
  echo "FAIL existing /games surface"
  fail=1
}

exit "$fail"
