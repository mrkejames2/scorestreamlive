"""Read-only, secret-safe production support diagnostics."""

import os
from datetime import datetime, timezone
from pathlib import Path

from app.config import settings
from app.database import check_database_health
from app.logging_config import get_request_id


def _storage_status() -> dict:
    path = Path(settings.TEAM_LOGO_STORAGE_DIR)
    writable = path.is_dir() and os.access(path, os.W_OK)
    return {"team_logos": "writable" if writable else "unavailable"}


def _email_status() -> dict:
    mode = settings.EMAIL_DELIVERY_MODE
    if mode == "log":
        configured = True
    elif mode == "smtp":
        configured = bool(settings.SMTP_HOST and settings.EMAIL_FROM_ADDRESS)
    else:
        configured = False
    return {"mode": mode, "configured": configured}


def _socket_status() -> dict:
    raw = settings.SOCKET_CORS_ORIGINS.strip()
    if raw == "*":
        policy, count = "wildcard", 1
    elif raw:
        origins = [item.strip() for item in raw.split(",") if item.strip()]
        policy, count = "explicit", len(origins)
    else:
        policy, count = "same-origin", 0
    return {"origin_policy": policy, "configured_origin_count": count}


async def build_support_diagnostics() -> dict:
    """Build a Director-only snapshot without exposing credentials or tenant data."""
    database = await check_database_health()
    overall = "ok" if database["status"] == "ok" else "degraded"
    return {
        "status": overall,
        "server_time": datetime.now(timezone.utc).isoformat(),
        "application": {
            "name": settings.APP_NAME,
            "environment": settings.APP_ENV,
            "version": settings.APP_VERSION,
            "release": settings.APP_RELEASE,
        },
        "database": database,
        "storage": _storage_status(),
        "email": _email_status(),
        "socket": _socket_status(),
        "request_id": get_request_id(),
    }
