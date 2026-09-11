"""Verified billing-event durable inbox and replay-safe processing."""
from __future__ import annotations

from datetime import datetime, timezone
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.billing.provider import BillingProvider, VerifiedBillingEvent
from app.models.billing_event import BillingEvent
from app.services.account_activation_service import deliver_activation
from app.services.checkout_provisioning_service import ProvisioningRejected, process_completed_checkout

SUPPORTED_PROVISIONING_EVENT = "checkout.session.completed"

class BillingEventProcessingError(Exception):
    """Retryable or otherwise unresolved billing-event processing failure."""
    pass


class BillingEventRejected(BillingEventProcessingError):
    """Verified billing event was deterministically rejected."""
    pass


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


async def record_verified_event(db: AsyncSession, verified: VerifiedBillingEvent) -> BillingEvent:
    if not verified.external_event_id or not verified.event_type:
        raise BillingEventProcessingError("verified_event_missing_identity")
    existing = await db.scalar(select(BillingEvent).where(
        BillingEvent.provider == verified.provider,
        BillingEvent.external_event_id == verified.external_event_id,
    ))
    if existing is not None:
        return existing
    event = BillingEvent(
        provider=verified.provider,
        external_event_id=verified.external_event_id,
        event_type=verified.event_type,
        object_external_id=verified.object_external_id,
        provider_created_at=verified.provider_created_at,
        payload_digest=verified.payload_digest,
        processing_status="RECEIVED",
    )
    db.add(event)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        existing = await db.scalar(select(BillingEvent).where(
            BillingEvent.provider == verified.provider,
            BillingEvent.external_event_id == verified.external_event_id,
        ))
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


async def process_verified_event(
    db: AsyncSession, *, billing_event_id, verified: VerifiedBillingEvent,
    provider: BillingProvider
) -> str:
    event = await db.scalar(
        select(BillingEvent).where(BillingEvent.id == billing_event_id).with_for_update()
    )
    if event is None:
        raise BillingEventProcessingError("billing_event_not_found")
    if event.processing_status in ("PROCESSED", "IGNORED"):
        return event.processing_status
    event.attempt_count += 1
    event.last_error = None
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
        # Billing/provisioning is committed before any SMTP/network email delivery.
        await db.commit()
        if activation_delivery is not None:
            await deliver_activation(db, activation_delivery)
        return "PROCESSED"
    except ProvisioningRejected as exc:
        await _mark_failed(db, event.id, str(exc))
        raise BillingEventRejected(str(exc)) from exc
    except Exception as exc:
        await _mark_failed(db, event.id, f"provisioning_exception:{type(exc).__name__}")
        raise BillingEventProcessingError("provisioning_exception") from exc


async def reprocess_persisted_event(
    db: AsyncSession, *, billing_event_id, provider: BillingProvider
) -> str:
    event = await db.get(BillingEvent, billing_event_id)
    if event is None:
        raise BillingEventProcessingError("billing_event_not_found")
    if event.processing_status == "PROCESSED":
        return "PROCESSED"
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
