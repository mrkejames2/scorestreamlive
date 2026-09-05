#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
p(){ echo "PASS $1"; }
f(){ echo "FAIL $1"; fail=1; }
n(){ grep -Fq "$2" "$1" && p "$3" || f "$3"; }

n alembic/versions/20260905_0015_add_user_invitations.py 'down_revision="20260904_0014"' 'migration head'
n app/services/invitation_service.py 'secrets.token_urlsafe(48)' 'opaque token'
n app/services/invitation_service.py 'hash_invitation_token(raw)' 'hashed token persistence'
n app/services/invitation_service.py 'with_for_update()' 'single-use locking'
n app/auth/password_policy.py 'MIN_PASSWORD_LENGTH=10' 'password policy'
n app/web/activation.py 'set_session_cookie' 'automatic session'
n app/auth/security.py 'EMAIL_DELIVERY_MODE must be smtp in production' 'production email fail closed'
n templates/account/index.html 'Pending Invitations' 'pending invitation UI'
n static/js/account.js 'req("/api/admin/invitations"' 'invitation form API wiring'
n static/js/account.js 'function renderInvitations()' 'pending invitation renderer'
n static/js/account.js 'Open Activation Link' 'local activation preview'

if grep -Fq 'Temporary Password' templates/account/index.html; then
  f 'temporary password UI removed'
else
  p 'temporary password UI removed'
fi

if grep -Fq 'function renderSelectors() {\n' static/js/account.js; then
  f 'no literal backslash-n JavaScript corruption'
else
  p 'no literal backslash-n JavaScript corruption'
fi

if grep -Fq 'window.prompt("Local activation URL"' static/js/account.js; then
  f 'obsolete local activation prompt removed'
else
  p 'obsolete local activation prompt removed'
fi

if [[ -n "${BASE_URL:-}" ]]; then
  c="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/activate?token=invalid-m17d")"
  [[ "$c" == 400 ]] && p 'invalid token safe' || f "invalid token returned $c"
fi

exit "$fail"
