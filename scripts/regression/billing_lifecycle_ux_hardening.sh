#!/usr/bin/env bash
set -uo pipefail
fail=0
pass(){ echo "PASS: $1"; }
fail(){ echo "FAIL: $1"; fail=1; }
check(){ if eval "$2"; then pass "$1"; else fail "$1"; fi; }
echo "========================================"
echo "M18-H HARDENING2 Billing Lifecycle UX"
echo "========================================"
check "Games resolves CREATE_GAMES before allowing New Game" "grep -q loadCreateGameEntitlement static/js/games/index.js && grep -q 'entitlements?.CREATE_GAMES === true' static/js/games/index.js"
check "Games offers Billing recovery path when creation is unavailable" "grep -q 'Billing / Restore Access' static/js/games/index.js && grep -q '/account/billing' static/js/games/index.js"
check "Branding distinguishes expired subscription from plan exclusion" "grep -q \"subscription_status == 'EXPIRED'\" templates/account/branding.html && grep -q 'branding is saved' templates/account/branding.html"
check "Branding route supplies subscription lifecycle state" "grep -q 'select(Subscription.status)' app/web/branding.py && grep -q subscription_status app/web/branding.py"
check "Billing explains expired access without destructive language" "grep -q 'Subscription Expired' templates/account/billing.html && grep -q 'saved branding remain stored' templates/account/billing.html"
check "Billing restores authenticated navigation" "grep -q 'ssl-global-nav' templates/account/billing.html && grep -q 'href=\"/games\"' templates/account/billing.html && grep -q 'href=\"/teams\"' templates/account/billing.html"
check "Billing portal remains provider-managed" "grep -q '/api/billing/portal' static/js/billing.js"
python3 -m py_compile app/web/branding.py || fail=1
if [[ "$fail" -ne 0 ]]; then echo "M18-H HARDENING2 Billing Lifecycle UX: FAIL"; exit 1; fi
echo "M18-H HARDENING2 Billing Lifecycle UX: PASS"
