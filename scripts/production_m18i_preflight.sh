#!/usr/bin/env bash
set -euo pipefail
echo "M18-I production preflight (read-only)"
echo "APP_ENV=${APP_ENV:-unset}"
echo "PUBLIC_BASE_URL=${PUBLIC_BASE_URL:-unset}"
echo "BILLING_LIVE_ENABLED=${BILLING_LIVE_ENABLED:-unset}"
echo "PUBLIC_CHECKOUT_ENABLED=${PUBLIC_CHECKOUT_ENABLED:-unset}"
case "${STRIPE_SECRET_KEY:-}" in
  sk_test_*) echo "Stripe secret mode: TEST";;
  sk_live_*) echo "Stripe secret mode: LIVE";;
  "") echo "Stripe secret mode: UNSET";;
  *) echo "Stripe secret mode: UNKNOWN";;
esac
echo "This script intentionally does not print secrets or mutate the database."
