#!/usr/bin/env bash
set -uo pipefail
FAIL=0
pass(){ echo "PASS $*"; }
fail(){ echo "FAIL $*"; FAIL=1; }

echo "========================================"
echo "M18-C Hosted Checkout"
echo "========================================"

for f in \
  alembic/versions/20260907_0020_add_hosted_checkout_foundation.py \
  alembic/versions/20260907_0021_harden_hosted_checkout_recovery.py \
  app/models/billing_price_reference.py \
  app/models/checkout_attempt.py \
  app/billing/stripe_provider.py \
  app/billing/factory.py \
  app/services/checkout_service.py \
  app/api/public_checkout.py \
  app/web/checkout.py \
  static/checkout-success.html \
  static/checkout-cancel.html \
  scripts/configure_m18c_stripe_price.py; do
  [[ -f "$f" ]] && pass "file $f" || fail "file $f"
done

grep -Fq 'down_revision = "20260907_0019"' alembic/versions/20260907_0020_add_hosted_checkout_foundation.py \
  && pass "M18-C foundation extends M18-B hardening head" || fail "M18-C foundation migration head"
grep -Fq 'down_revision = "20260907_0020"' alembic/versions/20260907_0021_harden_hosted_checkout_recovery.py \
  && pass "M18-C hardening extends checkout foundation" || fail "M18-C hardening migration head"
grep -Fq 'signup_intent_id' app/models/billing_external_reference.py \
  && pass "external reference supports pre-provisioning ownership" || fail "external reference signup owner"
grep -Fq 'create_checkout' app/billing/provider.py \
  && pass "provider-neutral checkout contract" || fail "provider checkout contract"
grep -Fq 'import stripe' app/billing/stripe_provider.py \
  && pass "Stripe isolated to provider adapter" || fail "Stripe adapter"
! grep -R -E 'import stripe|from stripe' app/models app/services app/api --include='*.py' >/dev/null \
  && pass "domain/API do not import Stripe" || fail "Stripe leaked outside billing adapter"
grep -Fq 'CHECKOUT_STARTED' app/services/checkout_service.py \
  && pass "signup checkout transition" || fail "checkout transition"
grep -Fq 'browser return is not used as proof of payment' static/checkout-success.html \
  && pass "success page is non-authoritative" || fail "success page payment-truth wording"
! grep -R -E 'Subscription\(|Club\(|User\(' app/services/checkout_service.py app/api/public_checkout.py >/dev/null \
  && pass "checkout does not provision tenant/account/subscription" || fail "checkout provisioning leak"
grep -Fq 'stripe==15.6.1' requirements.txt \
  && pass "Stripe SDK pinned" || fail "Stripe SDK dependency"
grep -Fq 'STRIPE_SECRET_KEY' app/config.py \
  && pass "Stripe secret configured from environment" || fail "Stripe config"
grep -Fq 'uq_billing_price_active_plan_provider' alembic/versions/20260907_0021_harden_hosted_checkout_recovery.py \
  && pass "one active provider price per plan" || fail "active provider price uniqueness"
grep -Fq 'uq_checkout_attempt_active' alembic/versions/20260907_0021_harden_hosted_checkout_recovery.py \
  && pass "one active checkout attempt per signup/plan/provider" || fail "active checkout uniqueness"
grep -Fq 'attempt_id' app/services/checkout_service.py \
  && pass "provider idempotency is scoped to logical checkout attempt" || fail "attempt-scoped idempotency"
grep -Fq 'external_reference_owner_mismatch' app/services/checkout_service.py \
  && pass "external reference ownership collision fails closed" || fail "external reference collision handling"
grep -Fq 'parsed.scheme != "https"' app/services/checkout_service.py \
  && pass "provider checkout destination requires HTTPS" || fail "checkout URL validation"

sudo docker compose exec -T app python - <<'PY' || FAIL=1
import asyncio
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from app.billing.provider import CheckoutResult
from app.database import AsyncSessionLocal
from app.models import BillingExternalReference, Club, Plan, SignupIntent, Subscription, User
from app.models.billing_price_reference import BillingPriceReference
from app.models.checkout_attempt import CheckoutAttempt
from app.services.checkout_service import CheckoutRejected, create_checkout


class FakeProvider:
    name = "stripe"

    def __init__(self):
        self.calls = 0
        self.keys = []

    async def create_checkout(self, request):
        self.calls += 1
        self.keys.append(request.idempotency_key)
        aid = request.metadata["checkout_attempt_id"].replace("-", "")
        return CheckoutResult(
            external_checkout_id="cs_test_" + aid,
            checkout_url="https://checkout.example.invalid/session/" + aid,
            expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
        )

    def verify_webhook(self, payload, signature):
        raise NotImplementedError


class FlakyProvider(FakeProvider):
    async def create_checkout(self, request):
        self.calls += 1
        self.keys.append(request.idempotency_key)
        if self.calls == 1:
            raise RuntimeError("simulated lost response")
        aid = request.metadata["checkout_attempt_id"].replace("-", "")
        return CheckoutResult(
            external_checkout_id="cs_recovered_" + aid,
            checkout_url="https://checkout.example.invalid/recovered/" + aid,
            expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
        )


async def counts(db):
    return {
        "users": await db.scalar(select(func.count()).select_from(User)),
        "clubs": await db.scalar(select(func.count()).select_from(Club)),
        "subscriptions": await db.scalar(select(func.count()).select_from(Subscription)),
    }


async def run():
    marker = uuid.uuid4().hex
    email = f"m18c-{marker}@example.invalid"
    plan_code = f"M18C_{marker[:12].upper()}"

    async with AsyncSessionLocal() as db:
        baseline = await counts(db)
        plan = Plan(code=plan_code, name="M18C Validation", is_active=True)
        db.add(plan)
        await db.flush()
        price = BillingPriceReference(
            plan_id=plan.id,
            provider="stripe",
            external_price_id="price_" + marker,
            currency="usd",
            billing_interval="month",
            unit_amount_minor=100,
            is_active=True,
        )
        db.add(price)
        intent = SignupIntent(
            email=email,
            email_normalized=email,
            first_name="M18C",
            last_name="Validation",
            organization_name="Validation Org",
            status="READY_FOR_CHECKOUT",
            expires_at=datetime.now(timezone.utc) + timedelta(hours=2),
            source="validation",
        )
        db.add(intent)
        await db.commit()
        await db.refresh(plan)
        await db.refresh(intent)
        iid = intent.id
        pid = plan.id

    try:
        provider = FakeProvider()
        async with AsyncSessionLocal() as db:
            first = await create_checkout(
                db, signup_intent_id=iid, plan_code=plan_code, provider=provider
            )
            second = await create_checkout(
                db, signup_intent_id=iid, plan_code=plan_code, provider=provider
            )
            assert first.checkout_url == second.checkout_url
            assert provider.calls == 1

            attempts = (
                await db.scalars(
                    select(CheckoutAttempt)
                    .where(CheckoutAttempt.signup_intent_id == iid)
                    .order_by(CheckoutAttempt.created_at.asc())
                )
            ).all()
            assert len(attempts) == 1
            first_attempt = attempts[0]
            first_key = first_attempt.idempotency_key
            first_attempt.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
            await db.commit()

            replacement = await create_checkout(
                db, signup_intent_id=iid, plan_code=plan_code, provider=provider
            )
            assert provider.calls == 2
            attempts = (
                await db.scalars(
                    select(CheckoutAttempt)
                    .where(CheckoutAttempt.signup_intent_id == iid)
                    .order_by(CheckoutAttempt.created_at.asc())
                )
            ).all()
            assert len(attempts) == 2
            assert attempts[0].status == "EXPIRED"
            assert attempts[1].status == "OPEN"
            assert attempts[1].idempotency_key != first_key
            assert replacement.checkout_url != first.checkout_url
            print("PASS expired checkout creates a new logical attempt and provider key")

            refs = (
                await db.scalars(
                    select(BillingExternalReference).where(
                        BillingExternalReference.signup_intent_id == iid
                    )
                )
            ).all()
            assert len(refs) == 2

            assert await counts(db) == baseline
            print("PASS create/reuse/replace/reference/no-provisioning contract")

        # Database must reject ambiguous active Price mappings.
        async with AsyncSessionLocal() as db:
            db.add(
                BillingPriceReference(
                    plan_id=pid,
                    provider="stripe",
                    external_price_id="price_second_" + marker,
                    currency="usd",
                    billing_interval="month",
                    unit_amount_minor=200,
                    is_active=True,
                )
            )
            try:
                await db.commit()
            except IntegrityError:
                await db.rollback()
                print("PASS database rejects multiple active provider prices for one plan")
            else:
                raise AssertionError("second active plan/provider price was accepted")

        # A lost provider response must retain and later reuse the exact same key.
        recovery_email = f"m18c-recovery-{marker}@example.invalid"
        async with AsyncSessionLocal() as db:
            recovery_intent = SignupIntent(
                email=recovery_email,
                email_normalized=recovery_email,
                first_name="M18C",
                last_name="Recovery",
                organization_name="Validation Org",
                status="READY_FOR_CHECKOUT",
                expires_at=datetime.now(timezone.utc) + timedelta(hours=2),
                source="validation",
            )
            db.add(recovery_intent)
            await db.commit()
            await db.refresh(recovery_intent)
            rid = recovery_intent.id

        flaky = FlakyProvider()
        async with AsyncSessionLocal() as db:
            try:
                await create_checkout(
                    db, signup_intent_id=rid, plan_code=plan_code, provider=flaky
                )
            except CheckoutRejected:
                pass
            else:
                raise AssertionError("simulated provider failure did not reject checkout")

            attempt = await db.scalar(
                select(CheckoutAttempt).where(
                    CheckoutAttempt.signup_intent_id == rid
                )
            )
            assert attempt is not None and attempt.status == "CREATING"
            failed_key = attempt.idempotency_key
            attempt.updated_at = datetime.now(timezone.utc) - timedelta(minutes=1)
            await db.commit()

            recovered = await create_checkout(
                db, signup_intent_id=rid, plan_code=plan_code, provider=flaky
            )
            assert recovered.checkout_url.startswith("https://")
            assert flaky.calls == 2
            assert flaky.keys[0] == flaky.keys[1] == failed_key
            print("PASS interrupted provider call recovers with the same idempotency key")

        # A provider external ID already owned by another SignupIntent must fail closed.
        collision_email = f"m18c-collision-{marker}@example.invalid"
        owner_email = f"m18c-owner-{marker}@example.invalid"
        async with AsyncSessionLocal() as db:
            collision_intent = SignupIntent(
                email=collision_email,
                email_normalized=collision_email,
                first_name="M18C",
                last_name="Collision",
                organization_name="Validation Org",
                status="READY_FOR_CHECKOUT",
                expires_at=datetime.now(timezone.utc) + timedelta(hours=2),
                source="validation",
            )
            owner_intent = SignupIntent(
                email=owner_email,
                email_normalized=owner_email,
                first_name="M18C",
                last_name="Owner",
                organization_name="Validation Org",
                status="READY_FOR_CHECKOUT",
                expires_at=datetime.now(timezone.utc) + timedelta(hours=2),
                source="validation",
            )
            db.add_all([collision_intent, owner_intent])
            await db.commit()
            await db.refresh(collision_intent)
            await db.refresh(owner_intent)
            cid = collision_intent.id
            oid = owner_intent.id

        class CollisionProvider(FakeProvider):
            async def create_checkout(self, request):
                self.calls += 1
                self.keys.append(request.idempotency_key)
                return CheckoutResult(
                    external_checkout_id="cs_collision_" + marker,
                    checkout_url="https://checkout.example.invalid/collision",
                    expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
                )

        async with AsyncSessionLocal() as db:
            db.add(
                BillingExternalReference(
                    provider="stripe",
                    resource_type="checkout_session",
                    external_id="cs_collision_" + marker,
                    signup_intent_id=oid,
                )
            )
            await db.commit()

        collision_provider = CollisionProvider()
        async with AsyncSessionLocal() as db:
            try:
                await create_checkout(
                    db, signup_intent_id=cid, plan_code=plan_code, provider=collision_provider
                )
            except CheckoutRejected as exc:
                assert "safely correlated" in str(exc)
            else:
                raise AssertionError("external-reference ownership collision was accepted")
            attempt = await db.scalar(
                select(CheckoutAttempt).where(CheckoutAttempt.signup_intent_id == cid)
            )
            assert attempt is not None
            assert attempt.status == "FAILED"
            assert attempt.last_error == "external_reference_owner_mismatch"
            print("PASS external-reference ownership collision fails closed")

        # Invalid provider destinations must never be returned to the browser.
        bad_email = f"m18c-badurl-{marker}@example.invalid"
        async with AsyncSessionLocal() as db:
            bad_intent = SignupIntent(
                email=bad_email,
                email_normalized=bad_email,
                first_name="M18C",
                last_name="BadUrl",
                organization_name="Validation Org",
                status="READY_FOR_CHECKOUT",
                expires_at=datetime.now(timezone.utc) + timedelta(hours=2),
                source="validation",
            )
            db.add(bad_intent)
            await db.commit()
            await db.refresh(bad_intent)
            bid = bad_intent.id

        class BadUrlProvider(FakeProvider):
            async def create_checkout(self, request):
                self.calls += 1
                self.keys.append(request.idempotency_key)
                return CheckoutResult(
                    external_checkout_id="cs_badurl_" + marker,
                    checkout_url="http://not-secure.example.invalid/session",
                    expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
                )

        async with AsyncSessionLocal() as db:
            try:
                await create_checkout(
                    db, signup_intent_id=bid, plan_code=plan_code, provider=BadUrlProvider()
                )
            except CheckoutRejected as exc:
                assert "invalid checkout destination" in str(exc)
            else:
                raise AssertionError("non-HTTPS checkout URL was accepted")
            print("PASS non-HTTPS provider destination fails closed")

    finally:
        async with AsyncSessionLocal() as db:
            intents = (
                await db.scalars(
                    select(SignupIntent).where(
                        SignupIntent.email_normalized.like(f"%{marker}%")
                    )
                )
            ).all()
            for intent in intents:
                await db.delete(intent)
            plan = await db.scalar(select(Plan).where(Plan.code == plan_code))
            if plan:
                await db.delete(plan)
            await db.commit()


asyncio.run(run())
PY

sudo docker compose exec -T app python - <<'PY' || FAIL=1
import app.models
from app.database import Base

required = {
    "billing_price_references",
    "checkout_attempts",
    "billing_external_references",
}
missing = required - set(Base.metadata.tables)
assert not missing, missing

price_indexes = {i.name for i in Base.metadata.tables["billing_price_references"].indexes}
attempt_indexes = {i.name for i in Base.metadata.tables["checkout_attempts"].indexes}
assert "uq_billing_price_active_plan_provider" in price_indexes
assert "uq_checkout_attempt_active" in attempt_indexes

print("PASS SQLAlchemy metadata registers M18-C hardening indexes")
PY

if [[ "$FAIL" -eq 0 ]]; then
  echo "M18-C Hosted Checkout... PASS"
  exit 0
fi

echo "M18-C Hosted Checkout... FAIL"
exit 1
