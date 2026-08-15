# ScoreStreamLive — Architecture Decision Records

This file records architectural decisions that future AI sessions must preserve unless explicitly superseded.

## ADR-001 — Centralized Configuration

**Decision:** Keep environment-specific configuration centralized.

**Reason:** Avoid scattered environment logic and hard-coded secrets.

---

## ADR-002 — Structured Application Logging

**Decision:** Use structured application logging without exposing credentials.

---

## ADR-003 — Separate Liveness and Readiness

**Decision:**

```text
/health/live
/health/ready
```

have separate contracts.

---

## ADR-004 — PostgreSQL

**Decision:** PostgreSQL is the persistent authoritative database.

---

## ADR-005 — Async SQLAlchemy

**Decision:** Use SQLAlchemy 2.x async with asyncpg.

---

## ADR-006 — Alembic

**Decision:** Schema evolution is managed through Alembic migrations.

Never rewrite applied migration history casually.

---

## ADR-007 — Socket.IO in the Application Service

**Decision:** Use `python-socketio` ASGI integration in the same application service as FastAPI.

**Reason:** Avoid premature additional services.

---

## ADR-008 — PostgreSQL Is the Source of Truth

**Decision:** Browser or Socket.IO state is never authoritative persistent state.

---

## ADR-009 — REST Is the Mutation Boundary

**Decision:** Persistent business mutations enter through REST/service logic unless a future architecture explicitly changes this.

---

## ADR-010 — Domain Events After Commit

**Decision:** Socket.IO successful-state events are emitted only after database commit.

---

## ADR-011 — Roster Is Derived

**Decision:** Do not create a Roster table in the current architecture.

Roster:

```text
Players WHERE team_id = Team.id
```

---

## ADR-012 — roster:updated Is Invalidation-Only

Payload:

```json
{
  "team_id": "<team UUID>"
}
```

Clients refetch the roster.

---

## ADR-013 — Player Team Membership Is Immutable in Current Domain

Player transfer is deferred to a future explicit design.

---

## ADR-014 — Jersey Numbers Are Not Unique

Jersey number:

```text
nullable
0–999
duplicates allowed
```

---

## ADR-015 — Game Owns Current Score

**Decision:** Store:

```text
Game.home_score
Game.away_score
```

Do not add a separate `game_state` table for M7.

---

## ADR-016 — ScoringEvent Stores Scoring History

ScoringEvent is durable history.

Game score is current state.

Clients do not replay ScoringEvents to derive current score.

---

## ADR-017 — Scoring Player Is Optional

`ScoringEvent.player_id` is nullable.

Unknown/unavailable scorer does not require a fake Player.

---

## ADR-018 — M7 Soccer Scoring Value

M7 supports:

```text
goal = +1
```

A generic multi-point sports engine is deferred.

---

## ADR-019 — Atomic Concurrent Score Increment

**Decision:** Increment Game score with an atomic PostgreSQL update in the same transaction as ScoringEvent creation.

**Reason:** Prevent lost updates under simultaneous valid scoring requests.

Production validation proved zero lost increments for 10 concurrent goals.

---

## ADR-020 — M7 Socket.IO Scoring Contract

Successful scoring emits after commit:

```text
scoring_event:created
game:score_updated
```

in that order for a single mutation.

---

## ADR-021 — Checkpoint Development Model

New domain milestones should prefer:

```text
A Persistence
B REST / Service
C Socket.IO
D Client / Docs / Regression
```

with validation after every checkpoint.

---

## ADR-022 — Documentation Is a Milestone Gate

Before the next milestone:

```text
AI_HANDOFF.md
IMPLEMENTATION_MAP.md
CURRENT_MILESTONE_STATUS.md
relevant domain docs
```

must reflect production-validated reality.

---

## ADR-023 — No Premature Distributed Infrastructure

Do not introduce:

```text
Redis
NATS
Kafka
RabbitMQ
Kubernetes
CQRS
Event sourcing
distributed Socket.IO
microservice decomposition
```

without a demonstrated requirement.
