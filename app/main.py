"""ScoreStreamLive Bootstrap — Milestone 1."""

import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request

from app.config import settings
from app.logging_config import configure_logging

configure_logging(settings.LOG_LEVEL)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle application startup and shutdown events."""
    logger = logging.getLogger("app")
    logger.info(
        "Application startup",
        extra={
            "event": "application.startup",
            "environment": settings.APP_ENV,
            "version": settings.APP_VERSION,
        },
    )
    yield
    logger.info(
        "Application shutdown",
        extra={"event": "application.shutdown"},
    )


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    lifespan=lifespan,
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log incoming HTTP requests with structured metadata."""
    start_time = time.time()
    response = await call_next(request)
    duration_ms = (time.time() - start_time) * 1000

    logger = logging.getLogger("app")
    logger.info(
        "HTTP request",
        extra={
            "event": "http.request",
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": round(duration_ms, 2),
        },
    )
    return response


@app.get("/")
async def root():
    """Return application status."""
    return {
        "status": "running",
        "environment": settings.APP_ENV,
        "version": settings.APP_VERSION,
    }


@app.get("/health/live")
async def health_live():
    """Liveness probe. Confirms the application process is alive."""
    return {"status": "ok"}


@app.get("/health/ready")
async def health_ready():
    """Readiness probe. Confirms the application can accept traffic."""
    return {"status": "ready"}


@app.get("/info")
async def info():
    """Return application metadata from centralized configuration."""
    return {
        "application": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.APP_ENV,
    }