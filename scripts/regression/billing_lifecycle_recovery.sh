#!/usr/bin/env bash
set -uo pipefail

fail=0
pass(){ echo "PASS: $1"; }
fail(){ echo "FAIL: $1"; fail=1; }
check(){ if eval "$2"; then pass "$1"; else fail "$1"; fi; }

echo "========================================"
echo "M18-H Billing Recovery & Lifecycle Safety"
echo "========================================"

check "0025 follows accepted branding head" \
  "grep -Fq 'down_revision = \"20260913_0024\"' alembic/versions/20260915_0025_harden_subscription_lifecycle.py"
check "0026 follows M18-H lifecycle migration" \
  "grep -Fq 'down_revision = \"20260915_0025\"' alembic/versions/20260915_0026_harden_lifecycle_event_replay.py"
check "billing event persists subscription replay identity" \
  "grep -q subscription_external_id app/models/billing_event.py"
check "invoice lifecycle identity is persisted" \
  "grep -q 'subscription_external_id=_subscription_id(verified)' app/services/billing_event_service.py"
check "persisted lifecycle replay uses durable subscription identity" \
  "grep -q 'external_subscription_id = event.subscription_external_id' app/services/billing_event_service.py"
check "provider-neutral subscription retrieval remains isolated" \
  "grep -q retrieve_subscription app/billing/provider.py && grep -q retrieve_subscription app/billing/stripe_provider.py"
check "subscription mutation uses row lock" \
  "grep -q with_for_update app/services/subscription_lifecycle_service.py"
check "older provider event is rejected" \
  "grep -q 'event_created_at < watermark' app/services/subscription_lifecycle_service.py"
check "same provider event is idempotent" \
  "grep -q 'subscription.last_provider_event_id == event_id' app/services/subscription_lifecycle_service.py"
check "PAST_DUE grace remains centralized" \
  "grep -q BILLING_PAST_DUE_GRACE_DAYS app/services/entitlement_service.py"
check "branding effective projection remains entitlement based" \
  "grep -q CUSTOM_OVERLAY_BRANDING app/services/effective_branding_service.py"
check "branding projection does not delete stored configuration" \
  "! grep -q -E 'delete|unlink|remove' app/services/effective_branding_service.py"
check "duplicate billing event protection preserved" \
  "grep -q 'UniqueConstraint(\"provider\", \"external_event_id\"' app/models/billing_event.py"
check "browser success/cancel routes remain non-authoritative" \
  "! grep -R -nE 'status[[:space:]]*=[[:space:]]*\"(ACTIVE|PAST_DUE|CANCELED|EXPIRED)\"' app/web/checkout.py app/web/billing.py 2>/dev/null"
check "M18-H cumulative validation still starts at G3" \
  "grep -q validate_m18g3.sh scripts/validate_m18h.sh"

python3 -m py_compile \
  app/models/billing_event.py \
  app/models/subscription.py \
  app/billing/provider.py \
  app/billing/stripe_provider.py \
  app/services/subscription_lifecycle_service.py \
  app/services/billing_event_service.py \
  app/services/entitlement_service.py \
  app/config.py \
  alembic/versions/20260915_0025_harden_subscription_lifecycle.py \
  alembic/versions/20260915_0026_harden_lifecycle_event_replay.py \
  || fail=1

if [[ "$fail" -ne 0 ]]; then
  echo "M18-H Billing Recovery & Lifecycle Safety: FAIL"
  exit 1
fi

echo "M18-H Billing Recovery & Lifecycle Safety: PASS"
