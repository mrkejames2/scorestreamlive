"""Provider-neutral billing provider contract."""
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping, Protocol

@dataclass(frozen=True)
class VerifiedBillingEvent:
    provider: str
    external_event_id: str
    event_type: str
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

class BillingProvider(Protocol):
    name: str
    async def create_checkout(self, request: CheckoutRequest) -> CheckoutResult: ...
    def verify_webhook(self, payload: bytes, signature: str) -> VerifiedBillingEvent: ...
