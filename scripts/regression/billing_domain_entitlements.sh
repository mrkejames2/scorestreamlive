#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
pass(){ echo "PASS $*"; }
no(){ echo "FAIL $*"; fail=1; }
need_file(){ [[ -f "$1" ]] && pass "file $1" || no "missing $1"; }
need_text(){ grep -Fq "$2" "$1" && pass "$3" || no "$3"; }
forbid_text(){ if grep -Fq "$2" "$1"; then no "$3"; else pass "$3"; fi; }

for f in \
  app/models/plan.py \
  app/models/subscription.py \
  app/models/billing_external_reference.py \
  app/models/billing_event.py \
  app/billing/__init__.py \
  app/billing/provider.py \
  app/services/entitlement_service.py \
  alembic/versions/20260907_0017_add_billing_domain_and_entitlements.py \
  scripts/regression/billing_domain_entitlements.sh \
  scripts/validate_m18a.sh; do
  need_file "$f"
done

need_text app/models/subscription.py "PENDING" "subscription lifecycle includes PENDING"
need_text app/models/subscription.py "ACTIVE" "subscription lifecycle includes ACTIVE"
need_text app/models/subscription.py "PAST_DUE" "subscription lifecycle includes PAST_DUE"
need_text app/models/subscription.py "CANCELED" "subscription lifecycle includes CANCELED"
need_text app/models/subscription.py "EXPIRED" "subscription lifecycle includes EXPIRED"

need_text app/services/entitlement_service.py "CUSTOM_OVERLAY_BRANDING" "custom branding capability is provider-neutral"
need_text app/services/entitlement_service.py "legacy_default" "legacy compatibility is explicit per entitlement check"
need_text app/billing/provider.py "class BillingProvider" "provider abstraction exists"
need_text app/billing/provider.py "verify_webhook" "provider contract reserves verified webhook boundary"
need_text app/models/billing_event.py "external_event_id" "billing events track provider event identity"
need_text app/models/billing_event.py "payload_digest" "billing event audit avoids requiring raw payload storage"
need_text app/models/billing_external_reference.py "resource_type" "provider IDs use external references"
need_text app/models/billing_external_reference.py "CASE WHEN signup_intent_id IS NOT NULL THEN 1 ELSE 0 END" "external references have exactly one application owner"
need_text app/models/plan.py "class PlanEntitlement" "plan entitlement mapping exists"

for f in app/models/*.py app/services/*.py app/billing/*.py; do
  forbid_text "$f" "stripe_plan_id" "$f does not couple product behavior to Stripe plan IDs"
  forbid_text "$f" "paddle_product_id" "$f does not couple product behavior to Paddle product IDs"
done

need_text alembic/versions/20260907_0017_add_billing_domain_and_entitlements.py \
  'down_revision = "20260905_0016"' "M18-A migration extends accepted M17 schema head"
need_text alembic/versions/20260907_0017_add_billing_domain_and_entitlements.py \
  '"CUSTOM_OVERLAY_BRANDING"' "migration seeds custom-branding capability definition"
if grep -Eq 'create_index\("ix_(plans_code|entitlements_code|subscriptions_club_id)".*unique=True' alembic/versions/20260907_0017_add_billing_domain_and_entitlements.py; then
  no "M18-A migration creates redundant unique indexes"
else
  pass "M18-A migration avoids redundant unique indexes"
fi

if python3 -m compileall -q app/models app/billing app/services; then
  pass "Python billing/domain modules compile"
else
  no "Python billing/domain modules failed compile"
fi

# Import model metadata in the actual application dependency environment.
# This is read-only and does not create or mutate customer records.
if sudo docker compose exec -T app python3 - <<'PY'
from app.database import Base
import app.models  # noqa: F401

expected = {
    "plans",
    "entitlements",
    "plan_entitlements",
    "subscriptions",
    "billing_external_references",
    "billing_events",
}
missing = expected.difference(Base.metadata.tables)
assert not missing, f"missing SQLAlchemy tables: {sorted(missing)}"
PY
then
  pass "SQLAlchemy metadata registers all M18-A tables"
else
  no "SQLAlchemy metadata registration failed"
fi

# M18-A deliberately contains no provider SDK coupling or commercial HTTP flow.
if grep -R -Eqi \
    --include='*.py' \
    --exclude='billing_webhooks.py' \
    '(^|[^[:alnum:]_])(stripe|paddle)([^[:alnum:]_]|$)' \
    app/api app/web app/main.py 2>/dev/null; then
  no "M18-A unexpectedly adds provider-specific product HTTP behavior"
else
  pass "M18-A adds no provider-specific product HTTP behavior"
fi

for term in redis kafka nats rabbitmq celery kubernetes; do
  if grep -R -Eqi "(^|[^[:alnum:]_])${term}([^[:alnum:]_]|$)" \
      app/billing app/models/plan.py app/models/subscription.py \
      app/models/billing_external_reference.py app/models/billing_event.py \
      app/services/entitlement_service.py 2>/dev/null; then
    no "M18-A unexpectedly introduces $term"
  else
    pass "M18-A does not introduce $term"
  fi
done

exit "$fail"
