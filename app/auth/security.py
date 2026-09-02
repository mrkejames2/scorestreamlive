"""M16-C request-boundary and production security helpers."""

from urllib.parse import urlparse

from fastapi import HTTPException, Request, status

from app.config import settings


def validate_production_security_settings() -> list[str]:
    """Return unsafe production configuration findings."""
    if settings.APP_ENV != "production":
        return []

    findings: list[str] = []

    if not settings.AUTH_SESSION_COOKIE_SECURE:
        findings.append("AUTH_SESSION_COOKIE_SECURE must be true in production")

    if not settings.DB_PASSWORD or settings.DB_PASSWORD == "change-me":
        findings.append("DB_PASSWORD must not use the development default in production")

    if settings.SOCKET_CORS_ORIGINS.strip() == "*":
        findings.append("SOCKET_CORS_ORIGINS must not be '*' in production")

    return findings


def enforce_production_security_settings() -> None:
    """Fail startup when production security configuration is unsafe."""
    findings = validate_production_security_settings()
    if findings:
        raise RuntimeError(
            "Unsafe production security configuration: " + "; ".join(findings)
        )


def require_same_origin_mutation(request: Request) -> None:
    """Reject cross-origin browser mutations when Origin is supplied."""
    if request.method.upper() not in {"POST", "PUT", "PATCH", "DELETE"}:
        return

    origin = request.headers.get("origin")
    if not origin:
        return

    try:
        parsed = urlparse(origin)
    except ValueError:
        parsed = None

    actual = (
        f"{parsed.scheme}://{parsed.netloc}"
        if parsed is not None and parsed.scheme and parsed.netloc
        else ""
    )
    expected = f"{request.url.scheme}://{request.headers.get('host', '')}"

    if not actual or actual.rstrip("/") != expected.rstrip("/"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cross-origin mutation denied",
        )
