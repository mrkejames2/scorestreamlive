"""Stripe-hosted Checkout adapter. Stripe remains isolated to this module."""
import asyncio
from datetime import datetime, timezone
import stripe
from app.billing.provider import CheckoutRequest, CheckoutResult, VerifiedBillingEvent

class StripeBillingProvider:
    name = "stripe"
    def __init__(self, secret_key: str):
        if not secret_key:
            raise RuntimeError("STRIPE_SECRET_KEY is not configured")
        self._secret_key = secret_key

    async def create_checkout(self, request: CheckoutRequest) -> CheckoutResult:
        def _create():
            return stripe.checkout.Session.create(
                api_key=self._secret_key,
                mode="subscription",
                customer_email=request.customer_email,
                line_items=[{"price": request.external_price_id, "quantity": 1}],
                success_url=request.success_url,
                cancel_url=request.cancel_url,
                metadata=dict(request.metadata),
                idempotency_key=request.idempotency_key,
            )
        session = await asyncio.to_thread(_create)
        expires_at = None
        if getattr(session, "expires_at", None):
            expires_at = datetime.fromtimestamp(session.expires_at, tz=timezone.utc)
        return CheckoutResult(session.id, session.url, expires_at)

    def verify_webhook(self, payload: bytes, signature: str) -> VerifiedBillingEvent:
        raise NotImplementedError("Verified webhook processing belongs to M18-D")
