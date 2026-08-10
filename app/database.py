"""Database connection layer."""

import logging
from urllib.parse import quote_plus

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import settings

logger = logging.getLogger("app")


def get_database_url() -> str:
    """Construct the async PostgreSQL connection URL."""
    password = quote_plus(settings.DB_PASSWORD)
    url = (
        f"postgresql+asyncpg://{settings.DB_USER}:{password}"
        f"@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
    )
    # Render PostgreSQL requires SSL
    if settings.APP_ENV == "production":
        url += "?ssl=require"
    return url


def get_safe_database_url() -> str:
    """Return the database URL with the password masked for safe logging."""
    return (
        f"postgresql+asyncpg://{settings.DB_USER}:****"
        f"@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
    )


# Use a short connection timeout (10s) instead of asyncpg's default 60s
# so failures are visible quickly in logs
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
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception as exc:
        # Use repr() because some asyncpg exceptions have empty str()
        logger.warning(
            "Database connection failed: %s",
            repr(exc),
            extra={
                "event": "database.connection.failure",
                "error_type": type(exc).__name__,
                "db_host": settings.DB_HOST,
                "db_port": settings.DB_PORT,
                "db_name": settings.DB_NAME,
                "db_user": settings.DB_USER,
                "db_url": get_safe_database_url(),
            },
        )
        return False