"""M16-C/M16-E request-boundary and production security helpers."""

from urllib.parse import urlparse

from fastapi import HTTPException, Request, status

from app.config import settings


def _normalize_origin(value: str) -> str:
    """Return a canonical scheme://host origin or an empty string."""
    try:
        parsed = urlparse(value.strip())
    except ValueError:
        return ""

    if not parsed.scheme or not parsed.netloc:
        return ""
    if parsed.path not in {"", "/"} or parsed.params or parsed.query or parsed.fragment:
        return ""
    return f"{parsed.scheme.lower()}://{parsed.netloc.lower()}".rstrip("/")


def _configured_production_origins() -> set[str]:
    """Return normalized explicit production origins from Socket.IO CORS config."""
    origins: set[str] = set()
    for value in settings.SOCKET_CORS_ORIGINS.split(","):
        normalized = _normalize_origin(value)
        if normalized:
            origins.add(normalized)
    return origins


def validate_production_security_settings() -> list[str]:
    """Return unsafe production configuration findings."""
    if settings.APP_ENV != "production":
        return []

    findings: list[str] = []

    if not settings.AUTH_SESSION_COOKIE_SECURE:
        findings.append("AUTH_SESSION_COOKIE_SECURE must be true in production")

    if not settings.DB_PASSWORD or settings.DB_PASSWORD == "change-me":
        findings.append("DB_PASSWORD must not use the development default in production")

    raw_origins = settings.SOCKET_CORS_ORIGINS.strip()
    if raw_origins == "*":
        findings.append("SOCKET_CORS_ORIGINS must not be '*' in production")
    else:
        origins = _configured_production_origins()
        if not origins:
            findings.append(
                "SOCKET_CORS_ORIGINS must contain at least one valid production origin"
            )
        elif any(not origin.startswith("https://") for origin in origins):
            findings.append("SOCKET_CORS_ORIGINS must use https origins in production")

    return findings


def enforce_production_security_settings() -> None:
    """Fail startup when production security configuration is unsafe."""
    findings = validate_production_security_settings()
    if findings:
        raise RuntimeError(
            "Unsafe production security configuration: " + "; ".join(findings)
        )


def require_same_origin_mutation(request: Request) -> None:
    """Reject cross-origin browser mutations when Origin is supplied.

    In production, compare against the explicit Socket.IO origin allowlist rather
    than request.url.scheme. This is stable behind Render's reverse proxy and
    avoids trusting client-supplied forwarded-protocol headers. Development and
    local validation continue to compare against the request's own origin.
    """
    if request.method.upper() not in {"POST", "PUT", "PATCH", "DELETE"}:
        return

    origin = request.headers.get("origin")
    if not origin:
        return

    actual = _normalize_origin(origin)

    if settings.APP_ENV == "production":
        expected_origins = _configured_production_origins()
        allowed = bool(actual) and actual in expected_origins
    else:
        expected = _normalize_origin(
            f"{request.url.scheme}://{request.headers.get('host', '')}"
        )
        allowed = bool(actual) and actual == expected

    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cross-origin mutation denied",
        )
