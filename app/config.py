"""Centralized application configuration."""

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    """Application settings loaded from environment variables."""

    APP_NAME: str = os.getenv("APP_NAME", "ScoreStreamLive")
    APP_ENV: str = os.getenv("APP_ENV", "development")
    APP_VERSION: str = os.getenv("APP_VERSION", "0.1.0")
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")


settings = Settings()