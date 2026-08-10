# Architecture

## Overview

ScoreStreamLive Bootstrap is a minimal, Dockerized FastAPI application serving as the operational foundation for all future ScoreStreamLive milestones.

## Components

| Component | Responsibility |
|-----------|--------------|
| **FastAPI** | ASGI web framework exposing HTTP endpoints. |
| **Uvicorn** | ASGI server running the FastAPI application. |
| **Docker** | Containerization ensuring identical behavior across environments. |
| **Docker Compose** | Local orchestration for development and testing. |
| **Render** | Cloud platform for production deployment. |
| **python-dotenv** | Local `.env` file loading for development. |

## Design Decisions

- **Centralized configuration:** All settings are loaded once from environment variables into an immutable `Settings` object in `app/config.py`.
- **No root user:** The container runs as an unprivileged user (`appuser`).
- **Structured logging:** JSON-formatted logs via Python's standard library for observability without external services.
- **Health separation:** Liveness (`/health/live`) and readiness (`/health/ready`) are distinct endpoints following cloud-native conventions.
- **Slim base image:** `python:3.13-slim` minimizes size and attack surface.
- **No additional services:** Databases, caches, frontends, and reverse proxies are excluded from Milestone 1.

## Request Flow
