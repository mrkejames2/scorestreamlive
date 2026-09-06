"""Database connection layer."""

import logging
import time
from urllib.parse import quote_plus

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

logger = logging.getLogger("app")


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy models."""
    pass


def get_database_url() -> str:
    """Construct the async PostgreSQL connection URL."""
    password = quote_plus(settings.DB_PASSWORD)
    url = (
        f"postgresql+asyncpg://{settings.DB_USER}:{password}"
        f"@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
    )
    if settings.APP_ENV == "production":
        url += "?ssl=require"
    return url


def get_safe_database_url() -> str:
    """Return the database URL with the password masked for safe logging."""
    return (
        f"postgresql+asyncpg://{settings.DB_USER}:****"
        f"@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
    )


engine = create_async_engine(
    get_database_url(),
    echo=settings.APP_ENV == "development",
    future=True,
    connect_args={"timeout": 10},
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_session() -> AsyncSession:
    """Yield an async database session for FastAPI dependency injection."""
    async with AsyncSessionLocal() as session:
        yield session


async def check_database_health() -> dict:
    """Return read-only PostgreSQL connectivity status and latency."""
    started = time.perf_counter()
    safe_url = get_safe_database_url()
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        logger.info(
            "Database connection OK: %s",
            safe_url,
            extra={"event": "database.connection.success", "latency_ms": latency_ms},
        )
        return {"status": "ok", "latency_ms": latency_ms}
    except Exception as exc:
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        logger.warning(
            "Database connection FAILED for %s — error: %s",
            safe_url,
            repr(exc),
            extra={
                "event": "database.connection.failure",
                "error_type": type(exc).__name__,
                "latency_ms": latency_ms,
            },
        )
        return {"status": "unavailable", "latency_ms": latency_ms}


async def check_database_connection() -> bool:
    """Execute a lightweight connectivity check against PostgreSQL."""
    result = await check_database_health()
    return result["status"] == "ok"
