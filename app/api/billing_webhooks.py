"""Provider webhook ingress. Browser return routes have no billing authority."""
import logging

import stripe
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.billing.factory import get_billing_provider
from app.billing.provider import BillingProvider
from app.database import get_session
from app.services.billing_event_service import (
    BillingEventProcessingError,
    BillingEventRejected,
    process_verified_event,
    record_verified_event,
)

router = APIRouter(prefix="/api/billing/webhooks", tags=["billing-webhooks"])
logger = logging.getLogger("app")


@router.post("/stripe")
async def stripe_webhook(request: Request, db: AsyncSession = Depends(get_session)):
    raw_payload = await request.body()
    signature = request.headers.get("Stripe-Signature", "")
    if not signature:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid webhook signature")
    try:
        provider: BillingProvider = get_billing_provider()
        verified = provider.verify_webhook(raw_payload, signature)
    except (stripe.error.SignatureVerificationError, ValueError):
        logger.warning("Stripe webhook signature verification failed", extra={"event": "billing.webhook.signature_rejected"})
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid webhook signature")
    except RuntimeError:
        logger.exception("Stripe webhook configuration unavailable", extra={"event": "billing.webhook.configuration_error"})
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Webhook processing unavailable")

    persisted = await record_verified_event(db, verified)
    if persisted.processing_status in ("PROCESSED", "IGNORED"):
        return {"received": True, "status": persisted.processing_status.lower(), "duplicate": True}
    try:
        result = await process_verified_event(
            db,
            billing_event_id=persisted.id,
            verified=verified,
            provider=provider,
        )
    except BillingEventRejected:
        logger.warning(
            "Verified billing event permanently rejected",
            extra={
                "event": "billing.webhook.processing_rejected",
                "billing_event_id": str(persisted.id),
                "provider_event_id": verified.external_event_id,
            },
        )
        return {
            "received": True,
            "status": "failed",
            "duplicate": False,
            "retryable": False,
        }
    except BillingEventProcessingError:
        logger.exception(
            "Verified billing event processing failed",
            extra={
                "event": "billing.webhook.processing_failed",
                "billing_event_id": str(persisted.id),
                "provider_event_id": verified.external_event_id,
            },
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Verified webhook processing failed",
        )

    return {
        "received": True,
        "status": result.lower(),
        "duplicate": False,
        "retryable": False,
    }
