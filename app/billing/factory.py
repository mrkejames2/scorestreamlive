"""Configured billing-provider factory."""
from app.billing.provider import BillingProvider
from app.billing.safety import enforce_billing_safety_settings
from app.billing.stripe_provider import StripeBillingProvider
from app.config import settings


def get_billing_provider() -> BillingProvider:
    enforce_billing_safety_settings()
    provider = settings.BILLING_PROVIDER.strip().lower()
    if provider != "stripe":
        raise RuntimeError(f"Unsupported BILLING_PROVIDER: {provider}")
    return StripeBillingProvider(settings.STRIPE_SECRET_KEY, settings.STRIPE_WEBHOOK_SECRET)
