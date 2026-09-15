"""Stripe adapter. Provider-specific behavior stays isolated here."""
import asyncio
import hashlib
from datetime import datetime, timezone
from typing import Any, Mapping

import stripe

from app.billing.provider import (
    BillingPortalRequest, BillingPortalResult, CheckoutRequest, CheckoutResult,
    ProviderSubscriptionSnapshot, VerifiedBillingEvent,
)

def _recursive_dict(value: Any) -> dict[str, Any]:
    if hasattr(value, "to_dict_recursive"):
        return value.to_dict_recursive()
    if hasattr(value, "to_dict"):
        return value.to_dict()
    if isinstance(value, Mapping):
        return dict(value)
    return {}

def _timestamp(value: Any) -> datetime | None:
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value, tz=timezone.utc)
    return None

class StripeBillingProvider:
    name = "stripe"

    def __init__(self, secret_key: str, webhook_secret: str = ""):
        if not secret_key:
            raise RuntimeError("STRIPE_SECRET_KEY is not configured")
        self._secret_key = secret_key
        self._webhook_secret = webhook_secret

    async def create_checkout(self, request: CheckoutRequest) -> CheckoutResult:
        def _create():
            return stripe.checkout.Session.create(
                api_key=self._secret_key, mode="subscription",
                customer_email=request.customer_email,
                line_items=[{"price": request.external_price_id, "quantity": 1}],
                success_url=request.success_url, cancel_url=request.cancel_url,
                metadata=dict(request.metadata), idempotency_key=request.idempotency_key,
            )
        session = await asyncio.to_thread(_create)
        return CheckoutResult(
            session.id, session.url,
            _timestamp(getattr(session, "expires_at", None)),
        )

    async def create_billing_portal(self, request: BillingPortalRequest) -> BillingPortalResult:
        def _create():
            return stripe.billing_portal.Session.create(
                api_key=self._secret_key, customer=request.external_customer_id,
                return_url=request.return_url,
            )
        session = await asyncio.to_thread(_create)
        return BillingPortalResult(portal_url=str(session.url))

    def verify_webhook(self, payload: bytes, signature: str) -> VerifiedBillingEvent:
        if not self._webhook_secret:
            raise RuntimeError("STRIPE_WEBHOOK_SECRET is not configured")
        event = stripe.Webhook.construct_event(
            payload=payload, sig_header=signature, secret=self._webhook_secret
        )
        event_dict = _recursive_dict(event)
        external_event_id = str(getattr(event, "id", None) or event_dict.get("id") or "")
        event_type = str(getattr(event, "type", None) or event_dict.get("type") or "")
        event_data = getattr(event, "data", None)
        event_object = event_data.get("object") if isinstance(event_data, Mapping) else getattr(event_data, "object", None)
        event_data_dict = _recursive_dict(event_data)
        if event_object is None:
            event_object = event_data_dict.get("object")
        obj = _recursive_dict(event_object)
        if not obj:
            fallback_data = event_dict.get("data") or {}
            if isinstance(fallback_data, Mapping):
                fallback_object = fallback_data.get("object")
                obj = _recursive_dict(fallback_object) or (dict(fallback_object) if isinstance(fallback_object, Mapping) else {})
        created = getattr(event, "created", None)
        if created is None:
            created = event_dict.get("created")
        return VerifiedBillingEvent(
            provider=self.name,
            external_event_id=external_event_id,
            event_type=event_type,
            object_external_id=str(obj.get("id") or "") or None,
            provider_created_at=_timestamp(created),
            payload_digest=hashlib.sha256(payload).hexdigest(),
            data=obj,
        )

    async def retrieve_checkout_session(self, external_checkout_id: str) -> Mapping[str, Any]:
        def _retrieve():
            return stripe.checkout.Session.retrieve(
                external_checkout_id, api_key=self._secret_key,
                expand=["line_items.data.price", "subscription"],
            )
        return _recursive_dict(await asyncio.to_thread(_retrieve))

    async def retrieve_subscription(self, external_subscription_id: str) -> ProviderSubscriptionSnapshot:
        def _retrieve():
            return stripe.Subscription.retrieve(
                external_subscription_id, api_key=self._secret_key
            )
        obj = _recursive_dict(await asyncio.to_thread(_retrieve))
        external_id = str(obj.get("id") or "")
        if not external_id:
            raise ValueError("provider_subscription_missing_identity")
        return ProviderSubscriptionSnapshot(
            external_subscription_id=external_id,
            status=str(obj.get("status") or "").lower(),
            current_period_start=_timestamp(obj.get("current_period_start")),
            current_period_end=_timestamp(obj.get("current_period_end")),
            cancel_at_period_end=bool(obj.get("cancel_at_period_end", False)),
            canceled_at=_timestamp(obj.get("canceled_at")),
        )
