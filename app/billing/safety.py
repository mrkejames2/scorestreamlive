"""M18-I billing-mode safety checks."""
from urllib.parse import urlparse
from app.config import settings

def validate_billing_safety_settings() -> list[str]:
    findings=[]
    if settings.BILLING_PROVIDER.strip().lower() != "stripe":
        return findings
    key=settings.STRIPE_SECRET_KEY.strip()
    if key:
        if settings.BILLING_LIVE_ENABLED and key.startswith("sk_test_"):
            findings.append("BILLING_LIVE_ENABLED=true cannot use a Stripe test secret key")
        if not settings.BILLING_LIVE_ENABLED and key.startswith("sk_live_"):
            findings.append("BILLING_LIVE_ENABLED=false cannot use a Stripe live secret key")
    if settings.APP_ENV == "production":
        parsed=urlparse(settings.PUBLIC_BASE_URL)
        if parsed.scheme != "https" or not parsed.netloc:
            findings.append("PUBLIC_BASE_URL must be an absolute https URL in production")
        if settings.BILLING_LIVE_ENABLED:
            findings.append("M18-I production safety gate requires BILLING_LIVE_ENABLED=false")
    return findings

def enforce_billing_safety_settings() -> None:
    findings=validate_billing_safety_settings()
    if findings:
        raise RuntimeError("Unsafe billing configuration: " + "; ".join(findings))
