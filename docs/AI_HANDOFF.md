# ScoreStreamLive — AI HANDOFF

**Project:** ScoreStreamLive  
**Purpose:** Persistent project context for AI-assisted development  
**Current Completed Milestones:** 0–6  
**Current Milestone:** Milestone 6 — COMPLETE  
**Next Planned Milestone:** Milestone 7 — Game State / Scoring Foundation  
**Production Status:** Milestone 6 validated locally and on Render production

---

# 1. Purpose

AI chat history is not the project's source of truth.

At the start of a new AI session, provide:

- `AI_HANDOFF.md`
- `IMPLEMENTATION_MAP.md`
- the current `MILESTONE_X.md`
- the current repository

The repository and committed project documentation are authoritative.

This file explains what ScoreStreamLive is, what is complete, the AI workflow, core architectural guardrails, current production state, and the next milestone direction.

---

# 2. Project Overview

ScoreStreamLive is a sports-focused real-time game management and scoreboard platform.

The initial implementation is soccer-focused while keeping the core architecture suitable for additional sports later.

Expected product evolution:

```text
Game Management
      ↓
Teams
      ↓
Players / Rosters
      ↓
Game State
      ↓
Scoring
      ↓
Game Clock
      ↓
Scoreboard Projection
      ↓
Streaming / OBS
```

The project is intentionally developed in small, validated milestones.

---

# 3. Development Philosophy

ScoreStreamLive is being developed by a team of one with AI assistance.

> Build the smallest reliable architectural layer required for the next capability, validate it locally and in production, document the resulting implementation, and only then move forward.

Avoid premature complexity and future-feature implementation.

Each milestone must complete:

```text
Architecture
Implementation
Local Validation
Independent Review
Production Validation
Documentation Refresh
```

before the next milestone begins.

---

# 4. Mandatory Milestone Completion Gate

Before starting a new milestone:

```text
Milestone implementation
        ↓
Local Docker validation
        ↓
Regression validation
        ↓
DeepSeek independent review
        ↓
GPT architecture decision
        ↓
GitHub / Render deployment
        ↓
Production validation
        ↓
UPDATE AI_HANDOFF.md
        ↓
UPDATE IMPLEMENTATION_MAP.md
        ↓
Commit documentation
        ↓
Begin next milestone architecture
```

This documentation refresh is mandatory.

---

# 5. AI Workflow

```text
GPT
Solution Architect
   ↓
Kimi K2
Primary Developer
   ↓
Devin
Environment / Git / Deployment
   ↓
GitHub
   ↓
Render
   ↓
Production Validation
   ↓
DeepSeek
Independent Reviewer
   ↓
GPT
Final Architecture Decision
```

Rule:

> DeepSeek recommends. GPT decides. Kimi implements. Devin validates and deploys.

---

# 6. AI Responsibilities

## GPT
- Milestone architecture
- Domain boundaries
- API contracts
- DB relationships
- Socket.IO contracts
- Architecture decisions
- Acceptance criteria
- DeepSeek review decisions
- Scope control

## Kimi K2
- Read `AI_HANDOFF.md`
- Read `IMPLEMENTATION_MAP.md`
- Read active milestone spec
- Inspect repository before coding
- Implement approved architecture
- Preserve working behavior
- Work in checkpoints
- Update docs
- Avoid scope expansion

## Devin
- Local VM execution
- Docker
- Migrations
- Validation scripts
- Git
- GitHub
- Render
- Production validation

## DeepSeek
- Independent code review
- Architecture compliance
- REST
- PostgreSQL
- Socket.IO
- Validation
- Error handling
- Security
- Regression risk
- Documentation accuracy

Findings should be classified as:
`BLOCKER`, `REQUIRED FIX`, or `OPTIONAL IMPROVEMENT`.

---

# 7. Infrastructure

Local:
- Ubuntu VM
- Docker
- Docker Compose

Source control:
- GitHub

Production:
- Render

Database:
- PostgreSQL

Real-time:
- Socket.IO

Deployment flow:

```text
Local VM
   ↓
GitHub
   ↓
Render
   ↓
Production
```

---

# 8. Core Architecture Rules

1. **PostgreSQL is the source of truth.**
2. **REST is the mutation boundary.**
3. **Socket.IO communicates committed state changes.**
4. **Do not redesign working architecture without approval.**
5. **Avoid premature microservices.**
6. **Avoid Redis/Kafka/NATS/Kubernetes/CQRS/Event Sourcing until required.**
7. **The current milestone specification is authoritative.**
8. **The repository is the project memory.**

Canonical mutation flow:

```text
REST Request
     ↓
Validation
     ↓
Service
     ↓
PostgreSQL
     ↓
COMMIT
     ↓
REFRESH / Reload
     ↓
Socket.IO Event
     ↓
Connected Clients
```

---

# 9. Completed Milestones

## M0 — Deployment Foundation
Complete.

## M1 — Application Foundation
Complete.

## M2 — PostgreSQL Foundation
Complete.

## M3 — Socket.IO Foundation
Complete.

## M4 — Game / Match Foundation
Complete.

## M5 — Team Foundation
Complete.

## M6 — Player / Roster Foundation
**COMPLETE and production validated.**

Current domain:

```text
                    GAME
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
      HOME TEAM             AWAY TEAM
          │                     │
          ▼                     ▼
       PLAYERS                PLAYERS
```

---

# 10. M6 Player Architecture

Player fields:

```text
id
team_id
first_name
last_name
jersey_number
created_at
updated_at
```

Decisions:

```text
id
    UUID v4

team_id
    required
    immutable during M6
    FK → teams.id
    ON DELETE RESTRICT

first_name
    required
    max 255
    trim surrounding whitespace
    preserve capitalization

last_name
    same rules

jersey_number
    nullable integer
    0–999
    duplicates allowed
```

No separate Roster table was introduced.

---

# 11. M6 REST API

Implemented:

```text
POST   /api/players
GET    /api/players/{player_id}
PATCH  /api/players/{player_id}

GET    /api/teams/{team_id}/players
```

Player deletion and transfers are deferred.

Roster ordering:

```text
jersey_number ASC NULLS LAST
last_name ASC
first_name ASC
id ASC
```

---

# 12. M6 Socket.IO

Implemented:

```text
player:created
player:updated
roster:updated
```

Creation order:

```text
COMMIT
 ↓
REFRESH
 ↓
player:created
 ↓
roster:updated
```

Update order:

```text
COMMIT
 ↓
REFRESH
 ↓
player:updated
 ↓
roster:updated
```

`roster:updated` is invalidation-only:

```json
{
  "team_id": "<team UUID>"
}
```

Clients needing authoritative roster state call:

```text
GET /api/teams/{team_id}/players
```

---

# 13. M6 Validation

Regression harness:

```text
scripts/validate_m6.sh
```

Local result:

```text
57 passed
0 failed
```

Render production result:

```text
57 passed
0 failed
```

Coverage includes:
- Health
- Teams
- Games
- Players
- Roster retrieval
- Roster ordering
- Team isolation
- Validation errors
- Socket.IO connect/ack/events
- Event ordering
- Failed-mutation event suppression
- Disconnect/reconnect

Preserve this script as a regression asset.

---

# 14. Alembic State

Player migration:

```text
alembic/versions/20260813_0003_create_players_table.py
```

Revision:

```text
20260813_0003
```

This migration was intentionally preserved during a rollback because PostgreSQL had already reached that revision. It was later verified to match the final M6 schema.

Do not remove or rewrite it casually.

---

# 15. Current Production State

M6 is deployed and validated on Render.

Current production domain:

```text
Game
 ↓
Team
 ↓
Player
```

with REST, PostgreSQL, Socket.IO, Docker, GitHub, and Render working end-to-end.

---

# 16. Next Planned Milestone

## M7 — Game State / Scoring Foundation

Status:

```text
NOT YET ARCHITECTED
```

Expected high-level direction:

```text
Game
 ↓
Game State
 ↓
Score
 ↓
Scoring Events
```

Do not begin coding M7 until a dedicated `MILESTONE_7.md` is created and approved.

---

# 17. Fresh AI Session Procedure

At the beginning of a new AI conversation:

1. Provide `AI_HANDOFF.md`.
2. Provide `IMPLEMENTATION_MAP.md`.
3. Provide current milestone spec.
4. Provide repository access.
5. Require repository reconstruction.
6. Surface unresolved architecture decisions.
7. Obtain GPT approval before coding.
8. Implement in checkpoints.
9. Run cumulative regression validation after every checkpoint.

---

# 18. Source of Truth Hierarchy

When information conflicts:

```text
1. Approved architecture decisions
2. Current MILESTONE_X.md
3. Actual repository
4. Database migrations
5. IMPLEMENTATION_MAP.md
6. Current docs/
7. AI_HANDOFF.md
8. Prior AI chat history
```

---

# 19. End-of-Milestone Documentation Procedure

After every milestone:

```text
1. Complete local validation
2. Complete independent review
3. Deploy production
4. Complete production validation
5. Update AI_HANDOFF.md
6. Update IMPLEMENTATION_MAP.md
7. Update relevant docs/
8. Update validation scripts
9. Commit documentation
10. Only then architect the next milestone
```

---

# 20. Current Handoff Summary

```text
PROJECT
ScoreStreamLive

COMPLETED
M0 Deployment
M1 Application Foundation
M2 PostgreSQL
M3 Socket.IO
M4 Game
M5 Team
M6 Player / Roster

CURRENT DOMAIN
Game
 ↓
Team
 ↓
Player

SOURCE OF TRUTH
PostgreSQL

MUTATION BOUNDARY
REST

REAL-TIME DELIVERY
Socket.IO

LOCAL
Ubuntu VM + Docker Compose

SOURCE CONTROL
GitHub

PRODUCTION
Render

REGRESSION HARNESS
scripts/validate_m6.sh

LOCAL M6 VALIDATION
57 / 57 PASS

PRODUCTION M6 VALIDATION
57 / 57 PASS

NEXT
M7 Game State / Scoring Foundation
```

This file must be updated before each new milestone begins.
