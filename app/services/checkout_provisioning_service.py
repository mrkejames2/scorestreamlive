"""Atomic tenant provisioning from an authoritative completed Checkout Session."""
from __future__ import annotations

import secrets
import uuid
from datetime import datetime, timezone
from typing import Any, Mapping

from argon2 import PasswordHasher
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.billing.provider import VerifiedBillingEvent
from app.models.billing_event import BillingEvent
from app.models.billing_external_reference import BillingExternalReference
from app.models.billing_price_reference import BillingPriceReference
from app.models.checkout_attempt import CheckoutAttempt
from app.models.club import Club
from app.models.signup_intent import SignupIntent
from app.models.subscription import Subscription
from app.models.user import User

class ProvisioningRejected(Exception):
    pass


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _nonempty_str(value: Any) -> str:
    return str(value).strip() if value is not None else ""


def _metadata(checkout: Mapping[str, Any]) -> Mapping[str, Any]:
    value = checkout.get("metadata")
    return value if isinstance(value, Mapping) else {}


def _external_id(value: Any) -> str:
    if isinstance(value, Mapping):
        return _nonempty_str(value.get("id"))
    return _nonempty_str(value)


def _line_item_price_id(checkout: Mapping[str, Any]) -> str:
    line_items = checkout.get("line_items")
    if not isinstance(line_items, Mapping):
        return ""
    data = line_items.get("data")
    if not isinstance(data, list) or len(data) != 1:
        return ""
    item = data[0]
    if not isinstance(item, Mapping):
        return ""
    return _external_id(item.get("price"))


def _period(subscription: Any, key: str):
    if not isinstance(subscription, Mapping):
        return None
    value = subscription.get(key)
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value, tz=timezone.utc)
    return None


async def _external_ref(db: AsyncSession, *, provider: str, resource_type: str, external_id: str):
    return await db.scalar(select(BillingExternalReference).where(
        BillingExternalReference.provider == provider,
        BillingExternalReference.resource_type == resource_type,
        BillingExternalReference.external_id == external_id,
    ).with_for_update())


async def process_completed_checkout(db: AsyncSession, *, event: BillingEvent, verified: VerifiedBillingEvent, checkout: Mapping[str, Any]) -> None:
    now = utc_now()
    session_id = _nonempty_str(checkout.get("id"))
    if not session_id or session_id != event.object_external_id:
        raise ProvisioningRejected("checkout_session_identity_mismatch")
    if _nonempty_str(checkout.get("mode")) != "subscription":
        raise ProvisioningRejected("checkout_mode_mismatch")
    if _nonempty_str(checkout.get("status")) != "complete":
        raise ProvisioningRejected("checkout_not_complete")
    if _nonempty_str(checkout.get("payment_status")) not in ("paid", "no_payment_required"):
        raise ProvisioningRejected("checkout_payment_not_confirmed")

    metadata = _metadata(checkout)
    try:
        signup_intent_id = uuid.UUID(_nonempty_str(metadata.get("signup_intent_id")))
        checkout_attempt_id = uuid.UUID(_nonempty_str(metadata.get("checkout_attempt_id")))
        plan_id = uuid.UUID(_nonempty_str(metadata.get("plan_id")))
    except (ValueError, AttributeError):
        raise ProvisioningRejected("checkout_metadata_invalid")

    session_ref = await db.scalar(select(BillingExternalReference).where(
        BillingExternalReference.provider == event.provider,
        BillingExternalReference.resource_type == "checkout_session",
        BillingExternalReference.external_id == session_id,
    ).with_for_update())
    if session_ref is None or session_ref.signup_intent_id != signup_intent_id:
        raise ProvisioningRejected("checkout_session_owner_mismatch")

    intent = await db.scalar(select(SignupIntent).where(SignupIntent.id == signup_intent_id).with_for_update())
    if intent is None:
        raise ProvisioningRejected("signup_intent_not_found")

    attempt = await db.scalar(select(CheckoutAttempt).where(CheckoutAttempt.id == checkout_attempt_id).with_for_update())
    if attempt is None or attempt.signup_intent_id != intent.id or attempt.plan_id != plan_id or attempt.provider != event.provider:
        raise ProvisioningRejected("checkout_attempt_mismatch")

    if intent.status == "COMPLETED" and attempt.status == "COMPLETED":
        existing_user = await db.scalar(select(User).where(func.lower(User.email) == intent.email_normalized))
        if existing_user is None or existing_user.club_id is None:
            raise ProvisioningRejected("completed_signup_integrity_error")
        existing_sub = await db.scalar(select(Subscription).where(Subscription.club_id == existing_user.club_id))
        if existing_sub is None or existing_sub.status != "ACTIVE":
            raise ProvisioningRejected("completed_subscription_integrity_error")
        event.processing_status = "PROCESSED"
        event.processed_at = now
        event.last_error = None
        return

    if intent.status != "CHECKOUT_STARTED" or attempt.status != "OPEN":
        raise ProvisioningRejected("checkout_lifecycle_mismatch")

    price = await db.scalar(select(BillingPriceReference).where(
        BillingPriceReference.plan_id == plan_id,
        BillingPriceReference.provider == event.provider,
        BillingPriceReference.is_active.is_(True),
    ))
    if price is None:
        raise ProvisioningRejected("billing_price_reference_missing")
    purchased_price_id = _line_item_price_id(checkout)
    if not purchased_price_id or purchased_price_id != price.external_price_id:
        raise ProvisioningRejected("checkout_price_mismatch")

    customer_id = _external_id(checkout.get("customer"))
    subscription_obj = checkout.get("subscription")
    subscription_id = _external_id(subscription_obj)
    if not customer_id:
        raise ProvisioningRejected("stripe_customer_missing")
    if not subscription_id:
        raise ProvisioningRejected("stripe_subscription_missing")

    if await db.scalar(select(User.id).where(func.lower(User.email) == intent.email_normalized)) is not None:
        raise ProvisioningRejected("existing_user_conflict")
    if await _external_ref(db, provider=event.provider, resource_type="customer", external_id=customer_id) is not None:
        raise ProvisioningRejected("stripe_customer_owner_conflict")
    if await _external_ref(db, provider=event.provider, resource_type="subscription", external_id=subscription_id) is not None:
        raise ProvisioningRejected("stripe_subscription_owner_conflict")

    club = Club(name=intent.organization_name)
    db.add(club)
    await db.flush()

    unusable_password = PasswordHasher().hash(secrets.token_urlsafe(48))
    display_name = f"{intent.first_name} {intent.last_name}".strip() or None
    user = User(
        email=intent.email_normalized,
        display_name=display_name,
        password_hash=unusable_password,
        is_active=False,
        club_id=club.id,
        club_role="DIRECTOR",
    )
    db.add(user)

    app_subscription = Subscription(
        club_id=club.id,
        plan_id=plan_id,
        status="ACTIVE",
        provider=event.provider,
        current_period_start=_period(subscription_obj, "current_period_start"),
        current_period_end=_period(subscription_obj, "current_period_end"),
        cancel_at_period_end=bool(subscription_obj.get("cancel_at_period_end", False) if isinstance(subscription_obj, Mapping) else False),
    )
    db.add(app_subscription)
    await db.flush()

    db.add_all([
        BillingExternalReference(provider=event.provider, resource_type="customer", external_id=customer_id, club_id=club.id),
        BillingExternalReference(provider=event.provider, resource_type="subscription", external_id=subscription_id, subscription_id=app_subscription.id),
    ])

    intent.status = "COMPLETED"
    intent.completed_at = now
    intent.updated_at = now
    attempt.status = "COMPLETED"
    attempt.last_error = None
    attempt.updated_at = now
    event.processing_status = "PROCESSED"
    event.processed_at = now
    event.last_error = None
