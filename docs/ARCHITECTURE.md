# Architecture

## Overview

ScoreStreamLive is a minimal, Dockerized FastAPI application designed to serve as the foundational deployment layer for all future ScoreStreamLive milestones.

## Components

| Component | Responsibility |
|-----------|--------------|
| **FastAPI** | ASGI web framework exposing HTTP endpoints. |
| **Uvicorn** | ASGI server running the FastAPI application. |
| **Docker** | Containerization ensuring identical behavior across environments. |
| **Docker Compose** | Local orchestration for development and testing. |
| **Render** | Cloud platform for production deployment. |

## Design Decisions

- **No root user:** The container runs as an unprivileged user (`appuser`) to reduce attack surface.
- **Environment variables:** All environment-specific values (e.g., `ENVIRONMENT`, `APP_VERSION`) are injected via environment variables rather than hard-coded.
- **Slim base image:** Uses `python:3.13-slim` to minimize image size and attack surface.
- **No additional services:** Databases, caches, frontends, and reverse proxies are intentionally excluded from Milestone 0.

## Request Flow
