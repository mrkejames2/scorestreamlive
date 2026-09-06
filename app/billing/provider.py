"""Provider-neutral billing provider contract for M18-A.

M18-A deliberately does not import or integrate Stripe, Paddle, or another
payment SDK. Concrete checkout/webhook behavior belongs to later M18 work.
"""
from dataclasses import dataclass
from typing import Any, Mapping, Protocol


@dataclass(frozen=True)
class VerifiedBillingEvent:
    """Normalized provider event produced only after provider verification."""

    provider: str
    external_event_id: str
    event_type: str
    payload_digest: str | None = None
    data: Mapping[str, Any] | None = None


class BillingProvider(Protocol):
    """Boundary implemented by the selected hosted-checkout provider later."""

    name: str

    def verify_webhook(self, payload: bytes, signature: str) -> VerifiedBillingEvent:
        """Verify authenticity and normalize an incoming provider event."""
        ...
