"""Centralized application configuration."""

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


def _get_db_port() -> int:
    """Safely parse DB_PORT from environment."""
    try:
        return int(os.getenv("DB_PORT", "5432"))
    except (ValueError, TypeError):
        return 5432


def _get_team_logo_max_bytes() -> int:
    """Safely parse the maximum accepted Team logo upload size."""
    try:
        value = int(os.getenv("TEAM_LOGO_MAX_BYTES", "2097152"))
    except (ValueError, TypeError):
        return 2 * 1024 * 1024
    return value if value > 0 else 2 * 1024 * 1024


def _get_auth_session_days() -> int:
    """Safely parse the authentication session lifetime."""
    try:
        value = int(os.getenv("AUTH_SESSION_DAYS", "30"))
    except (ValueError, TypeError):
        return 30
    return value if value > 0 else 30


def _get_positive_int(name: str, default: int) -> int:
    try:
        value = int(os.getenv(name, str(default)))
    except (ValueError, TypeError):
        return default
    return value if value > 0 else default


def _get_bool(name: str, default: bool) -> bool:
    """Read a conservative boolean environment setting."""
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    """Application settings loaded from environment variables."""

    APP_NAME: str = os.getenv("APP_NAME", "ScoreStreamLive")
    APP_ENV: str = os.getenv("APP_ENV", "development")
    APP_VERSION: str = os.getenv("APP_VERSION", "0.5.0")
    APP_RELEASE: str = os.getenv(
        "APP_RELEASE",
        os.getenv("RENDER_GIT_COMMIT", "unknown"),
    ).strip() or "unknown"
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    DB_HOST: str = os.getenv("DB_HOST", "postgres")
    DB_PORT: int = _get_db_port()
    DB_NAME: str = os.getenv("DB_NAME", "scorestreamlive")
    DB_USER: str = os.getenv("DB_USER", "scorestreamlive")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "change-me")
    SOCKET_CORS_ORIGINS: str = os.getenv("SOCKET_CORS_ORIGINS", "")

    TEAM_LOGO_STORAGE_DIR: str = os.getenv(
        "TEAM_LOGO_STORAGE_DIR",
        "static/uploads/team-logos",
    )
    TEAM_LOGO_MAX_BYTES: int = _get_team_logo_max_bytes()

    AUTH_SESSION_COOKIE_NAME: str = os.getenv(
        "AUTH_SESSION_COOKIE_NAME",
        "scorestreamlive_session",
    )
    AUTH_SESSION_DAYS: int = _get_auth_session_days()
    AUTH_SESSION_COOKIE_SECURE: bool = _get_bool(
        "AUTH_SESSION_COOKIE_SECURE",
        os.getenv("APP_ENV", "development") == "production",
    )

    PUBLIC_BASE_URL: str = os.getenv("PUBLIC_BASE_URL", "http://localhost:8000")
    INVITATION_TTL_HOURS: int = _get_positive_int("INVITATION_TTL_HOURS", 72)
    PASSWORD_RESET_TTL_MINUTES: int = _get_positive_int("PASSWORD_RESET_TTL_MINUTES", 60)
    PASSWORD_RESET_RESEND_SECONDS: int = _get_positive_int("PASSWORD_RESET_RESEND_SECONDS", 60)
    EMAIL_DELIVERY_MODE: str = os.getenv("EMAIL_DELIVERY_MODE", "log").strip().lower()
    SMTP_HOST: str = os.getenv("SMTP_HOST", "")
    SMTP_PORT: int = _get_positive_int("SMTP_PORT", 587)
    SMTP_USERNAME: str = os.getenv("SMTP_USERNAME", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    SMTP_USE_TLS: bool = _get_bool("SMTP_USE_TLS", True)
    EMAIL_FROM_ADDRESS: str = os.getenv("EMAIL_FROM_ADDRESS", "")
    EMAIL_FROM_NAME: str = os.getenv("EMAIL_FROM_NAME", "ScoreStreamLive")


settings = Settings()
