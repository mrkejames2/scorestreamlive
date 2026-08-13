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

# Architecture

## Overview

ScoreStreamLive is a Dockerized FastAPI application with a PostgreSQL persistence layer, serving as the operational and data foundation for all future milestones.

## Components

| Component | Responsibility |
|-----------|--------------|
| **FastAPI** | ASGI web framework exposing HTTP endpoints. |
| **Uvicorn** | ASGI server running the FastAPI application. |
| **PostgreSQL 16** | Persistent relational database. |
| **SQLAlchemy 2.0 (Async)** | Database access layer with async support. |
| **Alembic** | Database migration management. |
| **asyncpg** | Async PostgreSQL driver. |
| **Docker** | Containerization ensuring identical behavior across environments. |
| **Docker Compose** | Local orchestration for development and testing. |
| **Render** | Cloud platform for production deployment with managed PostgreSQL. |
| **python-dotenv** | Local `.env` file loading for development. |

## Design Decisions

- **Centralized configuration:** All settings are loaded once from environment variables into an immutable `Settings` object in `app/config.py`.
- **Async database layer:** SQLAlchemy 2.0 with `asyncpg` provides async database access compatible with FastAPI's async model.
- **Database URL construction:** The connection string is built programmatically from individual settings to avoid parsing secrets from a single URL.
- **No root user:** The container runs as an unprivileged user (`appuser`).
- **Structured logging:** JSON-formatted logs via Python's standard library.
- **Health separation:** Liveness (`/health/live`) is process-only; readiness (`/health/ready`) validates PostgreSQL connectivity.
- **Migration strategy:** Alembic manages schema migrations. Async configuration reads the database URL from the centralized settings layer.
- **Slim base image:** `python:3.13-slim` minimizes size and attack surface.

## Request Flow

# Architecture

## Overview

ScoreStreamLive is a Dockerized FastAPI application with PostgreSQL persistence and Socket.IO real-time communication.

## Components

| Component | Responsibility |
|-----------|--------------|
| **FastAPI** | ASGI web framework exposing HTTP endpoints. |
| **Uvicorn** | ASGI server running the combined FastAPI + Socket.IO application. |
| **Socket.IO** | Real-time bidirectional event communication. |
| **PostgreSQL 16** | Persistent relational database. |
| **SQLAlchemy 2.0 (Async)** | Database access layer. |
| **asyncpg** | Async PostgreSQL driver. |
| **Alembic** | Database migration management. |
| **Docker** | Containerization ensuring identical behavior across environments. |
| **Docker Compose** | Local orchestration for development and testing. |
| **Render** | Cloud platform for production deployment. |

## Design Decisions

- **Centralized configuration:** All settings loaded once from environment variables.
- **Async database layer:** SQLAlchemy 2.0 with `asyncpg`.
- **Socket.IO integration:** `python-socketio` with `async_mode='asgi'` mounted alongside FastAPI via `ASGIApp`. Single container serves both REST and Socket.IO.
- **No Redis:** Single-instance architecture proven before horizontal scaling.
- **No root user:** Container runs as `appuser`.
- **Structured logging:** JSON-formatted logs via Python standard library.

## Request Flow


---

## `docs/ARCHITECTURE.md`

**Purpose:** Updated to reflect the static files and explicit Socket.IO path.

```markdown
# Architecture

## Overview

ScoreStreamLive is a Dockerized FastAPI application with PostgreSQL persistence and Socket.IO real-time communication.

## Components

| Component | Responsibility |
|-----------|--------------|
| **FastAPI** | ASGI web framework exposing HTTP endpoints. |
| **Uvicorn** | ASGI server running the combined FastAPI + Socket.IO application. |
| **Socket.IO** | Real-time bidirectional event communication. |
| **PostgreSQL 16** | Persistent relational database. |
| **SQLAlchemy 2.0 (Async)** | Database access layer. |
| **asyncpg** | Async PostgreSQL driver. |
| **Alembic** | Database migration management. |
| **Docker** | Containerization ensuring identical behavior across environments. |
| **Docker Compose** | Local orchestration for development and testing. |
| **Render** | Cloud platform for production deployment. |

## Design Decisions

- **Centralized configuration:** All settings loaded once from environment variables.
- **Async database layer:** SQLAlchemy 2.0 with `asyncpg`.
- **Socket.IO integration:** `python-socketio` with `async_mode='asgi'` mounted alongside FastAPI via `socketio.ASGIApp`. Single container serves both REST and real-time communication.
- **Explicit Socket.IO path:** `/socket.io` is configured explicitly on both server and client.
- **Environment-aware CORS:** `SOCKET_CORS_ORIGINS` drives CORS behavior; production uses the service origin, local dev uses `*`.
- **No Redis:** Single-instance architecture proven before horizontal scaling.
- **No root user:** Container runs as `appuser`.
- **Structured logging:** JSON-formatted logs via Python standard library.

## Request Flow

# Architecture

## Overview

ScoreStreamLive is a Dockerized FastAPI application with PostgreSQL persistence, Socket.IO real-time communication, and a Game domain layer.

## Components

| Component | Responsibility |
|-----------|--------------|
| **FastAPI** | ASGI web framework exposing HTTP endpoints. |
| **Uvicorn** | ASGI server running FastAPI + Socket.IO. |
| **Socket.IO** | Real-time bidirectional event communication. |
| **PostgreSQL 16** | Persistent relational database. |
| **SQLAlchemy 2.0** | Async ORM and database access. |
| **Alembic** | Database schema migrations. |
| **Pydantic** | Request/response validation and serialization. |
| **Game Service** | Domain logic for Game lifecycle and Socket.IO notification. |

## Design Decisions

- **Domain layer:** Game operations are separated into `app/services/game_service.py`. REST routes do not contain business logic.
- **PostgreSQL as source of truth:** All Game state is persisted before Socket.IO events are emitted.
- **Socket.IO as notification:** The Socket.IO layer never writes to the database. It only broadcasts already-persisted state.
- **No rooms:** Game events are broadcast to all connected clients. Rooms will be introduced in a future milestone.
- **UUID identifiers:** Games use UUID primary keys for stability across REST and Socket.IO contexts.

## Data Flow


# Architecture

## Overview

ScoreStreamLive is a Dockerized FastAPI application with PostgreSQL persistence, Socket.IO real-time communication, and Team/Game domain layers.

## Components

| Component | Responsibility |
|-----------|--------------|
| **FastAPI** | ASGI web framework exposing HTTP endpoints. |
| **Uvicorn** | ASGI server running FastAPI + Socket.IO. |
| **Socket.IO** | Real-time bidirectional event communication. |
| **PostgreSQL 16** | Persistent relational database. |
| **SQLAlchemy 2.0** | Async ORM and database access. |
| **Alembic** | Database schema migrations. |
| **Pydantic** | Request/response validation and serialization. |
| **Team Service** | Team lifecycle and Socket.IO notification. |
| **Game Service** | Game lifecycle, Team validation, Socket.IO notification. |

## Design Decisions

- **Domain layer:** Team and Game operations are separated into service modules. REST routes contain no business logic.
- **PostgreSQL as source of truth:** All state is persisted before Socket.IO events are emitted.
- **Socket.IO as notification:** Never writes to the database. Only broadcasts already-persisted state.
- **Team independence:** Teams are standalone entities. Games reference them via foreign keys.
- **Nullable Team references:** Existing Games without Teams remain valid. New Games may omit Teams.
- **Embedded Team representation:** Game API responses include brief Team objects for client convenience.
- **No rooms:** Domain events broadcast to all connected clients. Rooms deferred.
- **UUID identifiers:** Stable across REST and Socket.IO contexts.

## Data Flow
