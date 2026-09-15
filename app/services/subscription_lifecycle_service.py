"""M18-H provider-neutral subscription lifecycle synchronization."""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.billing.provider import ProviderSubscriptionSnapshot
from app.models.billing_external_reference import BillingExternalReference
from app.models.subscription import Subscription


class LifecycleRejected(Exception):
    pass


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _domain_status(
    snapshot: ProviderSubscriptionSnapshot, existing: Subscription
) -> str:
    status = snapshot.status

    if status == "active":
        return "ACTIVE"
    if status in {"past_due", "unpaid"}:
        return "PAST_DUE"
    if status in {"incomplete", "incomplete_expired", "trialing", "paused"}:
        return "PENDING"
    if status == "canceled":
        # If cancellation was scheduled for period end, the provider's terminal
        # canceled state represents expiration of the paid-through subscription.
        if existing.cancel_at_period_end or snapshot.cancel_at_period_end:
            return "EXPIRED"
        return "CANCELED"

    raise LifecycleRejected(
        f"unsupported_provider_subscription_status:{status or 'missing'}"
    )


async def subscription_for_external_id(
    db: AsyncSession,
    *,
    provider: str,
    external_subscription_id: str,
    lock: bool = False,
) -> Subscription:
    stmt = (
        select(Subscription)
        .join(
            BillingExternalReference,
            BillingExternalReference.subscription_id == Subscription.id,
        )
        .where(
            BillingExternalReference.provider == provider,
            BillingExternalReference.resource_type == "subscription",
            BillingExternalReference.external_id == external_subscription_id,
        )
    )
    if lock:
        stmt = stmt.with_for_update()

    rows = (await db.scalars(stmt)).all()
    if len(rows) != 1:
        raise LifecycleRejected("subscription_external_reference_not_unique")
    return rows[0]


def event_is_stale(
    subscription: Subscription, *, event_created_at, event_id: str
) -> bool:
    watermark = subscription.last_provider_event_created_at
    if watermark is None or event_created_at is None:
        return False

    if event_created_at < watermark:
        return True

    # Same event is idempotent even when invoked outside the BillingEvent inbox.
    if (
        event_created_at == watermark
        and subscription.last_provider_event_id == event_id
    ):
        return True

    # Distinct provider events may legitimately share Stripe's second-resolution
    # created timestamp. They reconcile against current provider truth, so they
    # are not treated as stale merely because their timestamps tie.
    return False


async def apply_subscription_snapshot(
    db: AsyncSession,
    *,
    provider: str,
    snapshot: ProviderSubscriptionSnapshot,
    event_created_at,
    event_id: str,
) -> tuple[Subscription, bool]:
    subscription = await subscription_for_external_id(
        db,
        provider=provider,
        external_subscription_id=snapshot.external_subscription_id,
        lock=True,
    )

    if event_is_stale(
        subscription,
        event_created_at=event_created_at,
        event_id=event_id,
    ):
        return subscription, False

    subscription.status = _domain_status(snapshot, subscription)
    subscription.provider = provider
    subscription.current_period_start = snapshot.current_period_start
    subscription.current_period_end = snapshot.current_period_end
    subscription.cancel_at_period_end = snapshot.cancel_at_period_end
    subscription.canceled_at = snapshot.canceled_at

    current = subscription.last_provider_event_created_at
    if event_created_at is not None:
        if current is None or event_created_at >= current:
            subscription.last_provider_event_created_at = event_created_at
            subscription.last_provider_event_id = event_id
    elif subscription.last_provider_event_id is None:
        subscription.last_provider_event_id = event_id

    return subscription, True
