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


@dataclass(frozen=True)
class Settings:
    """Application settings loaded from environment variables."""

    APP_NAME: str = os.getenv("APP_NAME", "ScoreStreamLive")
    APP_ENV: str = os.getenv("APP_ENV", "development")
    APP_VERSION: str = os.getenv("APP_VERSION", "0.5.0")
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    DB_HOST: str = os.getenv("DB_HOST", "postgres")
    DB_PORT: int = _get_db_port()
    DB_NAME: str = os.getenv("DB_NAME", "scorestreamlive")
    DB_USER: str = os.getenv("DB_USER", "scorestreamlive")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "change-me")
    SOCKET_CORS_ORIGINS: str = os.getenv("SOCKET_CORS_ORIGINS", "")

    # M12-D2 Team-logo storage.
    #
    # This path is intentionally configurable. Local Docker uses a named volume.
    # A future production object-storage/disk adapter can preserve the same
    # public logo_url contract.
    TEAM_LOGO_STORAGE_DIR: str = os.getenv(
        "TEAM_LOGO_STORAGE_DIR",
        "static/uploads/team-logos",
    )
    TEAM_LOGO_MAX_BYTES: int = _get_team_logo_max_bytes()


settings = Settings()
