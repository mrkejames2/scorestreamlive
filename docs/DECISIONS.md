
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