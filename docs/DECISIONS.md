
---

## `docs/DECISIONS.md`

**Purpose:** Records key architecture and implementation decisions.

```markdown
# Architecture Decision Records

## ADR-001: Centralized Configuration via python-dotenv
**Date:** 2026-08-08  
**Decision:** Use `python-dotenv` with an immutable dataclass for settings.  
**Rationale:** Keeps configuration in one place. `.env` support for local development without code changes. Minimal dependency footprint.

## ADR-002: Standard Library JSON Logging
**Date:** 2026-08-08  
**Decision:** Implement structured logging using Python's standard `logging` module with a custom JSON formatter.  
**Rationale:** Avoids additional dependencies. Sufficient for Milestone 1 requirements. Can be replaced with a dedicated structured logging library in future milestones if needed.

## ADR-003: Separate Live vs Ready Health Endpoints
**Date:** 2026-08-08  
**Decision:** Split health into `/health/live` (process alive) and `/health/ready` (accepting traffic).  
**Rationale:** Follows Kubernetes/cloud-native conventions. Allows future extension for database and cache readiness checks without changing the liveness contract.



---

## `docs/DECISIONS.md`

**Purpose:** Records key architecture and implementation decisions.

```markdown
# Architecture Decision Records

## ADR-001: Centralized Configuration via python-dotenv
**Date:** 2026-08-08  
**Decision:** Use `python-dotenv` with an immutable dataclass for settings.  
**Rationale:** Keeps configuration in one place. `.env` support for local development without code changes.

## ADR-002: Standard Library JSON Logging
**Date:** 2026-08-08  
**Decision:** Implement structured logging using Python's standard `logging` module with a custom JSON formatter.  
**Rationale:** Avoids additional dependencies. Sufficient for current observability requirements.

## ADR-003: Separate Live vs Ready Health Endpoints
**Date:** 2026-08-08  
**Decision:** Split health into `/health/live` (process alive) and `/health/ready` (accepting traffic).  
**Rationale:** Follows Kubernetes/cloud-native conventions. Milestone 2 extends readiness to validate PostgreSQL.

## ADR-004: PostgreSQL 16
**Date:** 2026-08-09  
**Decision:** Use PostgreSQL 16 for both local development and production.  
**Rationale:** Explicit version pinning ensures consistency between local Docker and Render managed databases.

## ADR-005: SQLAlchemy 2.0 with Async Support
**Date:** 2026-08-09  
**Decision:** Use SQLAlchemy 2.0 with `asyncpg` as the database access layer.  
**Rationale:** Native async support aligns with FastAPI's async model. Provides a clear path to future ORM-based models while keeping the current layer minimal. Well-maintained with strong FastAPI community adoption.

## ADR-006: Alembic for Migrations
**Date:** 2026-08-09  
**Decision:** Use Alembic for database schema migrations.  
**Rationale:** Industry-standard companion to SQLAlchemy. Async-compatible configuration established in Milestone 2. No business migrations created yet.

## ADR-007: Individual Database Settings vs. Single URL
**Date:** 2026-08-09  
**Decision:** Store database connection components as individual settings (`DB_HOST`, `DB_PORT`, etc.) and construct the URL programmatically.  
**Rationale:** Aligns with Render's environment variable injection pattern. Avoids parsing a connection string to extract components for logging or other uses. Password is safely URL-encoded during construction.