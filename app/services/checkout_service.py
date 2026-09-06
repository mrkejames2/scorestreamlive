"""Hosted checkout orchestration without payment activation or provisioning."""
import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.billing.provider import BillingProvider, CheckoutRequest, CheckoutResult
from app.config import settings
from app.models.billing_external_reference import BillingExternalReference
from app.models.billing_price_reference import BillingPriceReference
from app.models.checkout_attempt import CheckoutAttempt
from app.models.plan import Plan
from app.models.signup_intent import SignupIntent
from app.models.user import User

CREATING_RETRY_AFTER = timedelta(seconds=30)


class CheckoutRejected(Exception):
    pass


def _idempotency_key(
    signup_intent_id: uuid.UUID,
    plan_id: uuid.UUID,
    provider: str,
    attempt_id: uuid.UUID,
) -> str:
    material = (
        f"scorestreamlive-checkout:{signup_intent_id}:{plan_id}:{provider}:{attempt_id}"
    ).encode()
    return "ssl-checkout-" + hashlib.sha256(material).hexdigest()


def _validated_checkout_url(value: str) -> str:
    if not value or len(value) > 2048:
        raise CheckoutRejected("Checkout provider returned an invalid checkout destination.")
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.hostname:
        raise CheckoutRejected("Checkout provider returned an invalid checkout destination.")
    return value


async def list_checkout_plans(db: AsyncSession, provider_name: str):
    rows = await db.execute(
        select(Plan, BillingPriceReference)
        .join(BillingPriceReference, BillingPriceReference.plan_id == Plan.id)
        .where(
            Plan.is_active.is_(True),
            BillingPriceReference.is_active.is_(True),
            BillingPriceReference.provider == provider_name,
        )
        .order_by(Plan.name.asc())
    )
    return rows.all()


async def _active_attempt(
    db: AsyncSession,
    *,
    signup_intent_id: uuid.UUID,
    plan_id: uuid.UUID,
    provider_name: str,
):
    return await db.scalar(
        select(CheckoutAttempt)
        .where(
            CheckoutAttempt.signup_intent_id == signup_intent_id,
            CheckoutAttempt.plan_id == plan_id,
            CheckoutAttempt.provider == provider_name,
            CheckoutAttempt.status.in_(("CREATING", "OPEN")),
        )
        .order_by(CheckoutAttempt.created_at.desc())
        .with_for_update()
    )


async def create_checkout(
    db: AsyncSession,
    *,
    signup_intent_id: uuid.UUID,
    plan_code: str,
    provider: BillingProvider,
) -> CheckoutResult:
    now = datetime.now(timezone.utc)

    intent = await db.scalar(
        select(SignupIntent)
        .where(SignupIntent.id == signup_intent_id)
        .with_for_update()
    )
    if intent is None or intent.status not in ("READY_FOR_CHECKOUT", "CHECKOUT_STARTED"):
        raise CheckoutRejected("Checkout cannot be started.")
    if intent.expires_at <= now:
        intent.status = "EXPIRED"
        intent.updated_at = now
        await db.commit()
        raise CheckoutRejected("This signup has expired. Please start again.")

    if await db.scalar(
        select(User.id).where(func.lower(User.email) == intent.email_normalized)
    ) is not None:
        raise CheckoutRejected("Checkout cannot be started.")

    plan = await db.scalar(
        select(Plan).where(Plan.code == plan_code, Plan.is_active.is_(True))
    )
    if plan is None:
        raise CheckoutRejected("The selected plan is unavailable.")

    price = await db.scalar(
        select(BillingPriceReference).where(
            BillingPriceReference.plan_id == plan.id,
            BillingPriceReference.provider == provider.name,
            BillingPriceReference.is_active.is_(True),
        )
    )
    if price is None:
        raise CheckoutRejected("Checkout is not configured for the selected plan.")

    attempt = await _active_attempt(
        db,
        signup_intent_id=intent.id,
        plan_id=plan.id,
        provider_name=provider.name,
    )

    if attempt is not None and attempt.status == "OPEN":
        if attempt.checkout_url and (
            attempt.expires_at is None or attempt.expires_at > now
        ):
            return CheckoutResult(
                external_checkout_id="persisted",
                checkout_url=attempt.checkout_url,
                expires_at=attempt.expires_at,
            )
        attempt.status = "EXPIRED"
        attempt.updated_at = now
        await db.commit()
        attempt = None

    if attempt is not None and attempt.status == "CREATING":
        if now - attempt.updated_at < CREATING_RETRY_AFTER:
            raise CheckoutRejected("Checkout is already being prepared. Please retry shortly.")
        # Reuse this exact attempt and key so a lost provider response is recovered
        # idempotently instead of creating a second provider Checkout Session.
        attempt.last_error = None
        attempt.updated_at = now
        await db.commit()

    if attempt is None:
        attempt_id = uuid.uuid4()
        key = _idempotency_key(intent.id, plan.id, provider.name, attempt_id)
        attempt = CheckoutAttempt(
            id=attempt_id,
            signup_intent_id=intent.id,
            plan_id=plan.id,
            provider=provider.name,
            status="CREATING",
            idempotency_key=key,
        )
        db.add(attempt)
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            active = await _active_attempt(
                db,
                signup_intent_id=intent.id,
                plan_id=plan.id,
                provider_name=provider.name,
            )
            if active is None:
                raise
            if active.status == "OPEN" and active.checkout_url and (
                active.expires_at is None or active.expires_at > datetime.now(timezone.utc)
            ):
                return CheckoutResult("persisted", active.checkout_url, active.expires_at)
            raise CheckoutRejected("Checkout is already being prepared. Please retry shortly.")

    request = CheckoutRequest(
        external_price_id=price.external_price_id,
        customer_email=intent.email_normalized,
        success_url=settings.PUBLIC_BASE_URL.rstrip("/") + "/checkout/success",
        cancel_url=settings.PUBLIC_BASE_URL.rstrip("/") + "/checkout/cancel",
        idempotency_key=attempt.idempotency_key,
        metadata={
            "signup_intent_id": str(intent.id),
            "checkout_attempt_id": str(attempt.id),
            "plan_id": str(plan.id),
        },
    )

    try:
        result = await provider.create_checkout(request)
    except Exception as exc:
        attempt = await db.get(CheckoutAttempt, attempt.id)
        if attempt is not None:
            # Keep CREATING so the exact same provider idempotency key can recover
            # a request whose response may have been lost after provider creation.
            attempt.last_error = type(exc).__name__
            attempt.updated_at = datetime.now(timezone.utc)
            await db.commit()
        raise CheckoutRejected("Checkout is temporarily unavailable. Please try again.") from exc

    try:
        checkout_url = _validated_checkout_url(result.checkout_url)
    except CheckoutRejected:
        attempt = await db.get(CheckoutAttempt, attempt.id)
        if attempt is not None:
            attempt.status = "FAILED"
            attempt.last_error = "invalid_checkout_url"
            attempt.updated_at = datetime.now(timezone.utc)
            await db.commit()
        raise

    attempt = await db.get(CheckoutAttempt, attempt.id)
    intent = await db.get(SignupIntent, intent.id)
    if attempt is None or intent is None:
        raise CheckoutRejected("Checkout could not be recorded.")

    ext = await db.scalar(
        select(BillingExternalReference).where(
            BillingExternalReference.provider == provider.name,
            BillingExternalReference.resource_type == "checkout_session",
            BillingExternalReference.external_id == result.external_checkout_id,
        )
    )
    if ext is not None and ext.signup_intent_id != intent.id:
        attempt.status = "FAILED"
        attempt.last_error = "external_reference_owner_mismatch"
        attempt.updated_at = datetime.now(timezone.utc)
        await db.commit()
        raise CheckoutRejected("Checkout could not be safely correlated.")

    if ext is None:
        db.add(
            BillingExternalReference(
                provider=provider.name,
                resource_type="checkout_session",
                external_id=result.external_checkout_id,
                signup_intent_id=intent.id,
            )
        )

    attempt.status = "OPEN"
    attempt.checkout_url = checkout_url
    attempt.expires_at = result.expires_at
    attempt.last_error = None
    attempt.updated_at = datetime.now(timezone.utc)

    intent.status = "CHECKOUT_STARTED"
    intent.checkout_started_at = (
        intent.checkout_started_at or datetime.now(timezone.utc)
    )
    intent.updated_at = datetime.now(timezone.utc)
    await db.commit()
    return CheckoutResult(
        external_checkout_id=result.external_checkout_id,
        checkout_url=checkout_url,
        expires_at=result.expires_at,
    )
