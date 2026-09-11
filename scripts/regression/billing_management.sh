#!/usr/bin/env bash
set -uo pipefail
fail=0; check(){ if eval "$2";then echo "PASS: $1";else echo "FAIL: $1";fail=1;fi; }
check "portal contract" "grep -q BillingPortalRequest app/billing/provider.py"
check "DIRECTOR auth" "grep -q require_current_user app/api/billing_management.py && grep -q DIRECTOR app/services/billing_management_service.py"
check "tenant-derived customer" "grep -q 'club_id==current_user.club_id' app/services/billing_management_service.py"
check "controlled return URL" "grep -q PUBLIC_BASE_URL app/services/billing_management_service.py"
check "web surface" "grep -q '/account/billing' app/web/billing.py"
python3 -m py_compile app/billing/provider.py app/services/billing_management_service.py app/api/billing_management.py app/web/billing.py || fail=1
[[ $fail -eq 0 ]]||exit 1;echo "M18-E2 Billing Management: PASS"
