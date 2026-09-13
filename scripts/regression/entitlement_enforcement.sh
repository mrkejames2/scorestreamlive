#!/usr/bin/env bash
set -uo pipefail
fail=0
check(){ if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

echo "========================================"
echo "M18-F Entitlement Enforcement"
echo "========================================"

check "explicit legacy policy" "grep -q LEGACY_ENTITLEMENT_DEFAULTS app/services/entitlement_service.py && grep -q 'CUSTOM_OVERLAY_BRANDING: False' app/services/entitlement_service.py"
check "ACTIVE-only paid access preserved" "grep -q 'return status == \"ACTIVE\"' app/services/entitlement_service.py"
check "HTTP entitlement adapter" "grep -q require_effective_club_entitlement app/auth/entitlements.py"
check "CREATE_GAMES enforced" "grep -q CREATE_GAMES app/api/games.py && grep -q require_entitlement app/api/games.py"
check "MANAGE_USERS enforced" "grep -q MANAGE_USERS app/api/club_admin.py && grep -q MANAGE_USERS app/api/invitations.py"
check "BROADCAST_OVERLAY enforced" "grep -q BROADCAST_OVERLAY app/api/control.py && grep -q BROADCAST_OVERLAY app/api/public_summary.py && grep -q BROADCAST_OVERLAY app/api/games.py"
check "entitlement summary exposed" "grep -q '/entitlements' app/api/entitlements.py"
check "billing and recovery ungated" "! grep -R -n require_entitlement app/api/billing_management.py app/web/account_activation.py app/web/password_recovery.py"
check "no Stripe dependency in entitlement runtime" "! grep -R -nE '(^|[[:space:]])import stripe|from stripe' app/services/entitlement_service.py app/auth/entitlements.py app/api/entitlements.py"
check "cumulative E2 preserved" "grep -q validate_m18e2.sh scripts/validate_m18f.sh"

python3 -m py_compile \
 app/services/entitlement_service.py app/auth/entitlements.py app/api/entitlements.py \
 app/api/games.py app/api/club_admin.py app/api/invitations.py \
 app/api/control.py app/api/public_summary.py || fail=1

[[ $fail -eq 0 ]] || { echo "M18-F Entitlement Enforcement: FAIL"; exit 1; }
echo "M18-F Entitlement Enforcement: PASS"
