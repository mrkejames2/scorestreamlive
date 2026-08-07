"""ScoreStreamLive Bootstrap - Minimal FastAPI application."""

import os

from fastapi import FastAPI

app = FastAPI(
    title="ScoreStreamLive Bootstrap",
    description="Foundational deployment platform for ScoreStreamLive.",
    version="0.0.1",
)


@app.get("/")
async def root():
    """Return application status and environment metadata."""
    return {
        "status": "running",
        "environment": os.getenv("ENVIRONMENT", "development"),
        "version": os.getenv("APP_VERSION", "0.0.1"),
    }


@app.get("/health")
async def health():
    """Return a simple health check response."""
    return {"status": "healthy"}