#!/usr/bin/env bash
set -euo pipefail
echo "========================================"
echo "M18-I Production Deployment & Billing Safety"
echo "========================================"
check(){ local label="$1" cmd="$2"; if eval "$cmd"; then echo "PASS: $label"; else echo "FAIL: $label"; exit 1; fi; }
check "billing live gate exists" "grep -q BILLING_LIVE_ENABLED app/config.py"
check "public checkout gate exists" "grep -q PUBLIC_CHECKOUT_ENABLED app/config.py && grep -q PUBLIC_CHECKOUT_ENABLED app/api/public_checkout.py"
check "production rejects live billing during M18-I" "grep -q 'M18-I production safety gate requires BILLING_LIVE_ENABLED=false' app/billing/safety.py"
check "test/live key mismatch protected" "grep -q sk_live_ app/billing/safety.py && grep -q sk_test_ app/billing/safety.py"
check "production URL is validated" "grep -q PUBLIC_BASE_URL app/billing/safety.py"
check "M18-H cumulative validation preserved" "grep -q validate_m18h scripts/validate_m18i.sh"
check "no M18-I migration introduced" "test ! -e alembic/versions/20260915_0027_m18i*"
echo "M18-I Production Deployment & Billing Safety: PASS"
