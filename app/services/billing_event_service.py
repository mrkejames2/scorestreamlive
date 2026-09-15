"""Verified billing-event durable inbox and replay-safe processing."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Mapping

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.billing.provider import BillingProvider, VerifiedBillingEvent
from app.models.billing_event import BillingEvent
from app.services.account_activation_service import deliver_activation
from app.services.checkout_provisioning_service import ProvisioningRejected, process_completed_checkout
from app.services.subscription_lifecycle_service import (
    LifecycleRejected,
    apply_subscription_snapshot,
    subscription_for_external_id,
)

SUPPORTED_PROVISIONING_EVENT = "checkout.session.completed"
SUPPORTED_LIFECYCLE_EVENTS = frozenset({
    "customer.subscription.updated",
    "customer.subscription.deleted",
    "invoice.payment_failed",
    "invoice.paid",
    "invoice.payment_succeeded",
})


class BillingEventProcessingError(Exception):
    pass


class BillingEventRejected(BillingEventProcessingError):
    pass


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _external_id(value: Any) -> str:
    if isinstance(value, Mapping):
        return str(value.get("id") or "").strip()
    return str(value or "").strip()


def _subscription_id(verified: VerifiedBillingEvent) -> str:
    data = verified.data or {}
    if verified.event_type.startswith("customer.subscription."):
        return _external_id(data.get("id")) or str(verified.object_external_id or "")
    if verified.event_type.startswith("invoice."):
        subscription = data.get("subscription")
        if isinstance(subscription, Mapping):
            return _external_id(subscription)
        return str(subscription or "").strip()
    return ""


async def record_verified_event(db: AsyncSession, verified: VerifiedBillingEvent) -> BillingEvent:
    if not verified.external_event_id or not verified.event_type:
        raise BillingEventProcessingError("verified_event_missing_identity")

    existing = await db.scalar(
        select(BillingEvent).where(
            BillingEvent.provider == verified.provider,
            BillingEvent.external_event_id == verified.external_event_id,
        )
    )
    if existing is not None:
        # Older rows may predate M18-H. Safely enrich only the replay identity.
        if not existing.subscription_external_id:
            subscription_id = _subscription_id(verified)
            if subscription_id:
                existing.subscription_external_id = subscription_id
                await db.commit()
                await db.refresh(existing)
        return existing

    event = BillingEvent(
        provider=verified.provider,
        external_event_id=verified.external_event_id,
        event_type=verified.event_type,
        object_external_id=verified.object_external_id,
        subscription_external_id=_subscription_id(verified) or None,
        provider_created_at=verified.provider_created_at,
        payload_digest=verified.payload_digest,
        processing_status="RECEIVED",
    )
    db.add(event)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        existing = await db.scalar(
            select(BillingEvent).where(
                BillingEvent.provider == verified.provider,
                BillingEvent.external_event_id == verified.external_event_id,
            )
        )
        if existing is None:
            raise
        return existing

    await db.refresh(event)
    return event


async def _mark_failed(db: AsyncSession, event_id, code: str) -> None:
    await db.rollback()
    event = await db.get(BillingEvent, event_id)
    if event is None:
        return
    event.attempt_count += 1
    event.processing_status = "FAILED"
    event.last_error = code[:1000]
    event.processed_at = None
    await db.commit()


async def _process_lifecycle(
    db: AsyncSession,
    *,
    event: BillingEvent,
    verified: VerifiedBillingEvent,
    provider: BillingProvider,
) -> str:
    external_subscription_id = (
        event.subscription_external_id or _subscription_id(verified)
    )
    if not external_subscription_id:
        raise BillingEventRejected("subscription_id_missing")

    if not event.subscription_external_id:
        event.subscription_external_id = external_subscription_id

    # Resolve local ownership before provider I/O. Do not hold a database row
    # lock while waiting on the provider.
    await subscription_for_external_id(
        db,
        provider=verified.provider,
        external_subscription_id=external_subscription_id,
        lock=False,
    )

    snapshot = await provider.retrieve_subscription(external_subscription_id)
    if snapshot.external_subscription_id != external_subscription_id:
        raise BillingEventRejected("subscription_identity_mismatch")

    # Re-lock the subscription and re-evaluate the ordering watermark immediately
    # before the durable mutation.
    _, applied = await apply_subscription_snapshot(
        db,
        provider=verified.provider,
        snapshot=snapshot,
        event_created_at=verified.provider_created_at,
        event_id=verified.external_event_id,
    )

    event.processing_status = "PROCESSED" if applied else "IGNORED"
    event.processed_at = utc_now()
    event.last_error = None if applied else "stale_provider_event"
    await db.commit()
    return event.processing_status


async def process_verified_event(
    db: AsyncSession,
    *,
    billing_event_id,
    verified: VerifiedBillingEvent,
    provider: BillingProvider,
) -> str:
    event = await db.scalar(
        select(BillingEvent)
        .where(BillingEvent.id == billing_event_id)
        .with_for_update()
    )
    if event is None:
        raise BillingEventProcessingError("billing_event_not_found")
    if event.processing_status in ("PROCESSED", "IGNORED"):
        return event.processing_status

    event.attempt_count += 1
    event.last_error = None

    if event.event_type in SUPPORTED_LIFECYCLE_EVENTS:
        try:
            return await _process_lifecycle(
                db, event=event, verified=verified, provider=provider
            )
        except BillingEventRejected:
            raise
        except LifecycleRejected as exc:
            await _mark_failed(db, event.id, str(exc))
            raise BillingEventRejected(str(exc)) from exc
        except Exception as exc:
            await _mark_failed(
                db, event.id, f"lifecycle_exception:{type(exc).__name__}"
            )
            raise BillingEventProcessingError("lifecycle_exception") from exc

    if event.event_type != SUPPORTED_PROVISIONING_EVENT:
        event.processing_status = "IGNORED"
        event.processed_at = utc_now()
        await db.commit()
        return "IGNORED"

    if not event.object_external_id:
        await _mark_failed(db, event.id, "checkout_session_id_missing")
        raise BillingEventRejected("checkout_session_id_missing")

    try:
        checkout = await provider.retrieve_checkout_session(event.object_external_id)
        activation_delivery = await process_completed_checkout(
            db, event=event, verified=verified, checkout=checkout
        )
        await db.commit()
        if activation_delivery is not None:
            await deliver_activation(db, activation_delivery)
        return "PROCESSED"
    except ProvisioningRejected as exc:
        await _mark_failed(db, event.id, str(exc))
        raise BillingEventRejected(str(exc)) from exc
    except Exception as exc:
        await _mark_failed(
            db, event.id, f"provisioning_exception:{type(exc).__name__}"
        )
        raise BillingEventProcessingError("provisioning_exception") from exc


async def reprocess_persisted_event(
    db: AsyncSession, *, billing_event_id, provider: BillingProvider
) -> str:
    event = await db.get(BillingEvent, billing_event_id)
    if event is None:
        raise BillingEventProcessingError("billing_event_not_found")
    if event.processing_status in ("PROCESSED", "IGNORED"):
        return event.processing_status

    if event.event_type in SUPPORTED_LIFECYCLE_EVENTS:
        external_subscription_id = event.subscription_external_id
        if not external_subscription_id:
            # Pre-M18-H customer.subscription rows remain recoverable because
            # object_external_id is the subscription ID. Legacy invoice rows
            # cannot be inferred safely and require provider redelivery once.
            if event.event_type.startswith("customer.subscription."):
                external_subscription_id = event.object_external_id
            if not external_subscription_id:
                raise BillingEventProcessingError(
                    "lifecycle_replay_missing_subscription_identity"
                )

        recovered = VerifiedBillingEvent(
            provider=event.provider,
            external_event_id=event.external_event_id,
            event_type=event.event_type,
            object_external_id=event.object_external_id,
            provider_created_at=event.provider_created_at,
            payload_digest=event.payload_digest,
            data={"id": external_subscription_id},
        )
        # _process_lifecycle prefers the persisted subscription_external_id.
        event.subscription_external_id = external_subscription_id
        await db.commit()
        return await process_verified_event(
            db,
            billing_event_id=event.id,
            verified=recovered,
            provider=provider,
        )

    if event.event_type != SUPPORTED_PROVISIONING_EVENT:
        event.processing_status = "IGNORED"
        event.processed_at = utc_now()
        event.last_error = None
        await db.commit()
        return "IGNORED"

    if not event.object_external_id:
        await _mark_failed(db, event.id, "checkout_session_id_missing")
        raise BillingEventRejected("checkout_session_id_missing")

    checkout = await provider.retrieve_checkout_session(event.object_external_id)
    recovered = VerifiedBillingEvent(
        provider=event.provider,
        external_event_id=event.external_event_id,
        event_type=event.event_type,
        object_external_id=event.object_external_id,
        provider_created_at=event.provider_created_at,
        payload_digest=event.payload_digest,
        data=checkout,
    )
    return await process_verified_event(
        db, billing_event_id=event.id, verified=recovered, provider=provider
    )
