"""Provider-neutral billing provider contract."""
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping, Protocol

@dataclass(frozen=True)
class VerifiedBillingEvent:
    provider: str
    external_event_id: str
    event_type: str
    object_external_id: str | None = None
    provider_created_at: datetime | None = None
    payload_digest: str | None = None
    data: Mapping[str, Any] | None = None

@dataclass(frozen=True)
class CheckoutRequest:
    external_price_id: str
    customer_email: str
    success_url: str
    cancel_url: str
    idempotency_key: str
    metadata: Mapping[str, str]

@dataclass(frozen=True)
class CheckoutResult:
    external_checkout_id: str
    checkout_url: str
    expires_at: datetime | None = None

@dataclass(frozen=True)
class BillingPortalRequest:
    external_customer_id: str
    return_url: str

@dataclass(frozen=True)
class BillingPortalResult:
    portal_url: str

@dataclass(frozen=True)
class ProviderSubscriptionSnapshot:
    external_subscription_id: str
    status: str
    current_period_start: datetime | None = None
    current_period_end: datetime | None = None
    cancel_at_period_end: bool = False
    canceled_at: datetime | None = None

class BillingProvider(Protocol):
    name: str
    async def create_checkout(self, request: CheckoutRequest) -> CheckoutResult: ...
    async def create_billing_portal(self, request: BillingPortalRequest) -> BillingPortalResult: ...
    def verify_webhook(self, payload: bytes, signature: str) -> VerifiedBillingEvent: ...
    async def retrieve_checkout_session(self, external_checkout_id: str) -> Mapping[str, Any]: ...
    async def retrieve_subscription(self, external_subscription_id: str) -> ProviderSubscriptionSnapshot: ...
