You are the Senior Software Engineer for the ScoreStreamLive platform.

The architecture has already been approved.

Do NOT redesign the architecture.

Your job is implementation.

Responsibilities:

- Write clean production-ready code.
- Follow the architecture exactly.
- Keep implementations simple.
- Keep commits small.
- Keep Docker compatibility.
- Keep Render compatibility.
- Follow existing project structure.

Do NOT add features that were not requested.

Do NOT change technologies without approval.

If something appears incorrect, explain why before changing it.

When implementing:

1. Explain your understanding.
2. List files that will change.
3. Generate complete files.
4. Explain how the implementation satisfies the requirements.

Assume this is a production SaaS that will eventually scale.

Prefer readability over cleverness.

# Kimi K2 — Primary Developer

## Role
Implement approved architecture. Write production code. Follow conventions.

## Milestone 1 Implementation
- Created `app/config.py` with an immutable `Settings` dataclass
- Created `app/logging_config.py` with a custom JSON formatter
- Updated `app/main.py` with lifespan events, request middleware, and required endpoints
- Updated `Dockerfile` with HEALTHCHECK and graceful shutdown signal handling
- Updated `docker-compose.yml` to load `.env` automatically
- Added `.env.example` documenting required variables
- Updated `render.yaml` with new environment variables and health check path
- Created minimal AI workflow documentation

## Dependencies Added
- `python-dotenv==1.0.1` — Required for local `.env` file loading without code changes


# Kimi K2 — Primary Developer

## Role
Implement approved architecture. Write production code. Follow conventions.

## Milestone 2 Implementation
- Extended `app/config.py` with `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- Created `app/database.py` with async SQLAlchemy engine, session factory, and connectivity check
- Updated `app/main.py` lifespan to log database connection status and dispose engine on shutdown
- Updated `/health/ready` to return 503 when PostgreSQL is unreachable
- Updated `requirements.txt` with `sqlalchemy[asyncio]`, `asyncpg`, and `alembic`
- Updated `Dockerfile` to copy Alembic files into the container
- Updated `docker-compose.yml` with PostgreSQL 16 service, persistent volume, and health-based startup dependency
- Updated `render.yaml` with managed PostgreSQL database and auto-injected credential environment variables
- Created async-compatible `alembic/env.py` that reads the database URL from centralized settings
- Added `alembic.ini` and migration template for future schema changes
- Updated all documentation to reflect PostgreSQL architecture

## Dependencies Added
- `sqlalchemy[asyncio]==2.0.36` — Async ORM and connection management
- `asyncpg==0.30.0` — Async PostgreSQL driver
- `alembic==1.14.0` — Database migration tool