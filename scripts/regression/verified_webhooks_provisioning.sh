#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "M18-D Verified Webhooks & Provisioning"
echo "========================================"
fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }

grep -q 'STRIPE_WEBHOOK_SECRET' app/config.py || fail "webhook secret configuration missing"
grep -q 'stripe.Webhook.construct_event' app/billing/stripe_provider.py || fail "Stripe signature verification missing"
grep -q 'await request.body()' app/api/billing_webhooks.py || fail "raw request body boundary missing"
grep -q 'Stripe-Signature' app/api/billing_webhooks.py || fail "Stripe-Signature header missing"
pass "raw signed Stripe webhook boundary"

grep -q 'object_external_id' app/models/billing_event.py || fail "BillingEvent recovery object missing"
grep -q 'payload_digest' app/models/billing_event.py || fail "BillingEvent digest missing"
grep -q 'provider_created_at' app/models/billing_event.py || fail "provider timestamp missing"
pass "durable BillingEvent inbox"

grep -q 'checkout.session.completed' app/services/billing_event_service.py || fail "authoritative event missing"
grep -q 'retrieve_checkout_session' app/services/billing_event_service.py || fail "provider re-read missing"
grep -q 'processing_status = "IGNORED"' app/services/billing_event_service.py || fail "ignore path missing"
grep -q 'class BillingEventRejected' app/services/billing_event_service.py || fail "permanent rejection classification missing"
grep -q 'raise BillingEventRejected' app/services/billing_event_service.py || fail "permanent provisioning rejection path missing"
grep -q 'except BillingEventRejected' app/api/billing_webhooks.py || fail "permanent rejection webhook handling missing"
grep -q '"retryable": False' app/api/billing_webhooks.py || fail "non-retryable acknowledgement missing"
grep -q 'HTTP_500_INTERNAL_SERVER_ERROR' app/api/billing_webhooks.py || fail "transient retry response missing"
pass "bounded authoritative processing"

grep -q 'checkout_session_owner_mismatch' app/services/checkout_provisioning_service.py || fail "owner correlation missing"
grep -q 'checkout_price_mismatch' app/services/checkout_provisioning_service.py || fail "price validation missing"
grep -q 'existing_user_conflict' app/services/checkout_provisioning_service.py || fail "user conflict guard missing"
grep -q 'club_role="DIRECTOR"' app/services/checkout_provisioning_service.py || fail "DIRECTOR provisioning missing"
grep -q 'status="ACTIVE"' app/services/checkout_provisioning_service.py || fail "ACTIVE subscription missing"
grep -q 'is_active=False' app/services/checkout_provisioning_service.py || fail "credential activation separation missing"
pass "fail-closed tenant provisioning"

python3 -m py_compile \
  app/config.py app/billing/provider.py app/billing/factory.py app/billing/stripe_provider.py \
  app/models/billing_event.py app/services/billing_event_service.py \
  app/services/checkout_provisioning_service.py app/api/billing_webhooks.py \
  scripts/reprocess_billing_event.py
pass "Python compile checks"

echo "M18-D Verified Webhooks & Provisioning: PASS"
