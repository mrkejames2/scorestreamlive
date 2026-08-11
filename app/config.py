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


@dataclass(frozen=True)
class Settings:
    """Application settings loaded from environment variables."""

    APP_NAME: str = os.getenv("APP_NAME", "ScoreStreamLive")
    APP_ENV: str = os.getenv("APP_ENV", "development")
    APP_VERSION: str = os.getenv("APP_VERSION", "0.3.0")
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    DB_HOST: str = os.getenv("DB_HOST", "postgres")
    DB_PORT: int = _get_db_port()
    DB_NAME: str = os.getenv("DB_NAME", "scorestreamlive")
    DB_USER: str = os.getenv("DB_USER", "scorestreamlive")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "change-me")
    SOCKET_CORS_ORIGINS: str = os.getenv("SOCKET_CORS_ORIGINS", "")


settings = Settings()