#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
fail=0
p(){ echo "PASS $1"; }; f(){ echo "FAIL $1"; fail=1; }
c(){ grep -Fq "$2" "$1" && p "$3" || f "$3"; }
c alembic/versions/20260905_0016_add_user_password_resets.py 'down_revision="20260905_0015"' 'migration ancestry'
c app/services/password_recovery_service.py 'secrets.token_urlsafe(48)' 'high entropy token'
c app/services/password_recovery_service.py 'hash_password_reset_token' 'hashed token'
c app/services/password_recovery_service.py '.with_for_update()' 'row lock'
c app/services/password_recovery_service.py 'delete(UserSession)' 'session revocation'
c app/services/password_recovery_service.py 'PASSWORD_RESET_RESEND_SECONDS' 'request suppression'
c app/services/access_admin_service.py 'revoke_outstanding_password_resets' 'deactivation revokes reset'
c app/web/password_recovery.py 'GENERIC_FORGOT_MESSAGE' 'generic public response'
c app/services/email_service.py 'password_reset.email.logged' 'recovery email log event'
c templates/auth/login.html 'Forgot your password?' 'login recovery navigation'
c templates/account/index.html 'Change Password' 'signed-in password UI'
c app/models/__init__.py 'UserPasswordReset' 'complete model registry'
c scripts/validate.sh "add 'Account Recovery & User Lifecycle'" 'domain #30 registered'
if [[ -n "${BASE_URL:-}" ]]; then
  code="$(curl -sS -o /tmp/m17e.$$ -w '%{http_code}' "$BASE_URL/forgot-password")"; [[ "$code" == 200 ]] && p 'forgot page public' || f "forgot page HTTP $code"; rm -f /tmp/m17e.$$
  code="$(curl -sS -o /tmp/m17e.$$ -w '%{http_code}' "$BASE_URL/reset-password?token=invalid-m17e")"; [[ "$code" == 400 ]] && p 'invalid token safe' || f "invalid token HTTP $code"; rm -f /tmp/m17e.$$
fi
exit "$fail"
