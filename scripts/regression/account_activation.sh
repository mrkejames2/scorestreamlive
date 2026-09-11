#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "M18-E1 Post-Purchase Account Activation"
echo "========================================"

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }

test -f app/models/user_account_activation.py || fail "activation model missing"
grep -q 'token_hash' app/models/user_account_activation.py || fail "hashed token field missing"
grep -q 'used_at' app/models/user_account_activation.py || fail "single-use state missing"
grep -q 'revoked_at' app/models/user_account_activation.py || fail "revocation state missing"
grep -q 'expires_at' app/models/user_account_activation.py || fail "expiration state missing"
pass "durable activation credential"

grep -q 'hashlib.sha256' app/services/account_activation_service.py || fail "SHA-256 token hashing missing"
grep -q 'secrets.token_urlsafe(48)' app/services/account_activation_service.py || fail "secure raw token generation missing"
grep -q 'user.is_active = True' app/services/account_activation_service.py || fail "user activation missing"
grep -q 'hash_password(password)' app/services/account_activation_service.py || fail "existing Argon2 password service not reused"
grep -q 'validate_password(password)' app/services/account_activation_service.py || fail "existing password policy not reused"
pass "secure activation consumption"

grep -q 'club_role != "DIRECTOR"' app/services/account_activation_service.py || fail "DIRECTOR eligibility boundary missing"
grep -q 'GENERIC_RESEND_MESSAGE' app/web/account_activation.py || fail "generic resend response missing"
grep -q 'require_same_origin_mutation' app/web/account_activation.py || fail "same-origin mutation boundary missing"
pass "authorization and anti-enumeration boundaries"

grep -q 'await db.commit()' app/services/billing_event_service.py || fail "provisioning commit missing"
grep -q 'await deliver_activation' app/services/billing_event_service.py || fail "post-commit activation delivery missing"
python3 - <<'PY'
from pathlib import Path
text=Path("app/services/billing_event_service.py").read_text()
commit=text.find("await db.commit()", text.find("activation_delivery ="))
deliver=text.find("await deliver_activation", commit)
assert commit >= 0 and deliver > commit, "activation email delivery must follow provisioning commit"
PY
pass "email delivery isolated from authoritative provisioning transaction"

grep -q 'except EmailDeliveryError' app/services/account_activation_service.py || fail "SMTP failure isolation missing"
grep -q 'return False' app/services/account_activation_service.py || fail "non-fatal delivery outcome missing"
pass "SMTP failure remains recoverable"

grep -q '/activate-account' app/web/account_activation.py || fail "activation route missing"
grep -q '/resend-activation' app/web/account_activation.py || fail "resend route missing"
grep -q 'account_activation_web_router' app/main.py || fail "activation router not registered"
pass "web activation surfaces"

grep -q 'browser return is not used as proof of payment' static/checkout-success.html || fail "non-authoritative checkout language regressed"
grep -q 'activation email' static/checkout-success.html || fail "post-purchase guidance missing"
grep -q '/resend-activation' static/checkout-success.html || fail "activation recovery link missing"
pass "checkout success guidance"

grep -q 'down_revision = "20260907_0022"' alembic/versions/20260910_0023_add_user_account_activations.py || fail "migration does not chain from M18-D head"
pass "Alembic migration chain"

# Existing invitation semantics must remain distinct.
grep -q 'club_role IN (' app/models/user_invitation.py || fail "existing invitation model missing"
grep -q 'MANAGER' app/models/user_invitation.py || fail "MANAGER invitation baseline missing"
grep -q 'OPERATOR' app/models/user_invitation.py || fail "OPERATOR invitation baseline missing"
grep -q 'activate_invitation' app/web/activation.py || fail "existing invitation route changed unexpectedly"
pass "M17 invitation activation preserved"

python3 -m py_compile \
  app/config.py \
  app/main.py \
  app/models/user_account_activation.py \
  app/services/email_service.py \
  app/services/account_activation_service.py \
  app/services/checkout_provisioning_service.py \
  app/services/billing_event_service.py \
  app/web/account_activation.py \
  alembic/versions/20260910_0023_add_user_account_activations.py
pass "Python compile checks"

echo "M18-E1 Post-Purchase Account Activation: PASS"
