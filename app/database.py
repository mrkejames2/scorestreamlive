"""Database connection layer."""

import logging
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


async def check_database_connection() -> bool:
    """Execute a lightweight connectivity check against PostgreSQL."""
    safe_url = get_safe_database_url()
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        logger.info("Database connection OK: %s", safe_url)
        return True
    except Exception as exc:
        logger.warning(
            "Database connection FAILED for %s — error: %s",
            safe_url,
            repr(exc),
            extra={
                "event": "database.connection.failure",
                "error_type": type(exc).__name__,
            },
        )
        return False