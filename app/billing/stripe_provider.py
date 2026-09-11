"""Stripe adapter. Provider-specific Checkout/webhook behavior stays isolated here."""
import asyncio
import hashlib
from datetime import datetime, timezone
from typing import Any, Mapping

import stripe

from app.billing.provider import BillingPortalRequest, BillingPortalResult, CheckoutRequest, CheckoutResult, VerifiedBillingEvent


def _recursive_dict(value: Any) -> dict[str, Any]:
    if hasattr(value, "to_dict_recursive"):
        return value.to_dict_recursive()
    if hasattr(value, "to_dict"):
        return value.to_dict()
    if isinstance(value, Mapping):
        return dict(value)
    return {}


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

    async def create_billing_portal(self, request: BillingPortalRequest) -> BillingPortalResult:
        def _create():
            return stripe.billing_portal.Session.create(
                api_key=self._secret_key,
                customer=request.external_customer_id,
                return_url=request.return_url,
            )
        session = await asyncio.to_thread(_create)
        return BillingPortalResult(portal_url=str(session.url))

    def verify_webhook(self, payload: bytes, signature: str) -> VerifiedBillingEvent:
        if not self._webhook_secret:
            raise RuntimeError("STRIPE_WEBHOOK_SECRET is not configured")
        event = stripe.Webhook.construct_event(
            payload=payload,
            sig_header=signature,
            secret=self._webhook_secret,
        )
        event_dict = _recursive_dict(event)

        # Stripe SDK Event objects expose authoritative identity as attributes.
        # Do not depend solely on recursive dictionary conversion for these
        # fields; SDK representation details can otherwise yield empty values.
        external_event_id = str(
            getattr(event, "id", None)
            or event_dict.get("id")
            or ""
        )
        event_type = str(
            getattr(event, "type", None)
            or event_dict.get("type")
            or ""
        )

        event_data = getattr(event, "data", None)

        # Stripe data containers may behave as either SDK objects or mappings.
        # Normalize both forms before extracting data.object.
        event_object = None
        if isinstance(event_data, Mapping):
            event_object = event_data.get("object")
        elif event_data is not None:
            event_object = getattr(event_data, "object", None)

        event_data_dict = _recursive_dict(event_data)
        if event_object is None:
            event_object = event_data_dict.get("object")

        obj = _recursive_dict(event_object)

        if not obj:
            fallback_data = event_dict.get("data") or {}
            if isinstance(fallback_data, Mapping):
                fallback_object = fallback_data.get("object")
                obj = _recursive_dict(fallback_object)
                if not obj and isinstance(fallback_object, Mapping):
                    obj = dict(fallback_object)

        created = getattr(event, "created", None)
        if created is None:
            created = event_dict.get("created")

        provider_created_at = None
        if isinstance(created, (int, float)):
            provider_created_at = datetime.fromtimestamp(created, tz=timezone.utc)

        return VerifiedBillingEvent(
            provider=self.name,
            external_event_id=external_event_id,
            event_type=event_type,
            object_external_id=str(obj.get("id") or "") or None,
            provider_created_at=provider_created_at,
            payload_digest=hashlib.sha256(payload).hexdigest(),
            data=obj,
        )

    async def retrieve_checkout_session(self, external_checkout_id: str) -> Mapping[str, Any]:
        def _retrieve():
            return stripe.checkout.Session.retrieve(
                external_checkout_id,
                api_key=self._secret_key,
                expand=["line_items.data.price", "subscription"],
            )
        return _recursive_dict(await asyncio.to_thread(_retrieve))
