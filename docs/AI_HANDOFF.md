# ScoreStreamLive --- AI HANDOFF

**Project:** ScoreStreamLive\
**Purpose:** Persistent project context for AI-assisted development\
**Production Baseline:** Milestones 0--6 complete and Render validated\
**Current Milestone:** Milestone 7 --- implementation and local
validation complete; independent review / production validation pending\
**Next Planned Milestone:** Milestone 8 --- Game Clock / Timer
Foundation\
**Rule:** Do not begin M8 until M7 is production validated and this
handoff is finalized.

------------------------------------------------------------------------

# 1. Purpose

AI chat history is not the project's source of truth.

At the start of a new AI session provide:

``` text
AI_HANDOFF.md
IMPLEMENTATION_MAP.md
Current MILESTONE_X.md
Current repository
```

The repository, committed migrations, approved architecture decisions,
and current project documentation are authoritative.

------------------------------------------------------------------------

# 2. Project Overview

ScoreStreamLive is a sports-focused real-time game management and
scoreboard platform.

Current evolution:

``` text
Game Management
      ↓
Teams
      ↓
Players / Rosters
      ↓
Game Score / Scoring Events   ← M7
      ↓
Game Clock                    ← planned M8
      ↓
Scoreboard Projection
      ↓
Streaming / OBS
```

The project is intentionally developed in small validated milestones.

------------------------------------------------------------------------

# 3. Development Philosophy

> Build the smallest reliable architectural layer required for the next
> capability, validate it locally and in production, document the
> resulting implementation, and only then move forward.

Every milestone must pass:

``` text
Architecture
Implementation
Local Validation
Independent Review
Production Validation
Documentation Refresh
```

before the next milestone begins.

------------------------------------------------------------------------

# 4. Mandatory Completion Gate

``` text
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
Begin next milestone
```

------------------------------------------------------------------------

# 5. AI Workflow

Normal workflow:

``` text
GPT
Solution Architect
   ↓
Kimi K2
Primary Developer
   ↓
Devin
Environment / Git / Deployment
   ↓
DeepSeek
Independent Reviewer
   ↓
GPT
Final Architecture Decision
```

During the end of M7, GPT temporarily performed the
implementation-engineer role while Kimi was unavailable. This does not
change the long-term role model.

Rule:

> DeepSeek recommends. GPT decides. Implementation follows approved
> architecture. Devin validates and deploys.

------------------------------------------------------------------------

# 6. Infrastructure

Local:

``` text
Ubuntu VM
Docker
Docker Compose
```

Application:

``` text
Python
FastAPI
SQLAlchemy async
asyncpg
PostgreSQL
Alembic
Pydantic
python-socketio
Uvicorn
```

Source control:

``` text
GitHub
```

Production:

``` text
Render
```

Deployment:

``` text
Local VM → GitHub → Render → Production Validation
```

------------------------------------------------------------------------

# 7. Core Architecture Rules

1.  **PostgreSQL is authoritative.**
2.  **REST is the persistent mutation boundary.**
3.  **Socket.IO communicates committed state changes.**
4.  **Never emit successful domain state before commit.**
5.  **Do not redesign working architecture without architecture
    approval.**
6.  **Avoid premature Redis, Kafka, NATS, Kubernetes, CQRS, event
    sourcing, or microservices.**
7.  **Current milestone scope is authoritative.**
8.  **The repository is project memory; AI conversation memory is not.**

Canonical mutation pattern:

``` text
REST
 ↓
Validation
 ↓
Service
 ↓
PostgreSQL
 ↓
COMMIT
 ↓
Reload committed state
 ↓
Socket.IO
 ↓
Connected Clients
```

------------------------------------------------------------------------

# 8. Completed Production Milestones

``` text
M0 Deployment Foundation        COMPLETE
M1 Application Foundation       COMPLETE
M2 PostgreSQL Foundation        COMPLETE
M3 Socket.IO Foundation         COMPLETE
M4 Game / Match Foundation      COMPLETE
M5 Team Foundation              COMPLETE
M6 Player / Roster Foundation   COMPLETE + PRODUCTION VALIDATED
```

M6 production regression:

``` text
scripts/validate_m6.sh
57 passed
0 failed
```

------------------------------------------------------------------------

# 9. Current M7 State

Milestone 7 is **not yet formally closed**, because independent review
and Render production validation remain.

Completed locally:

``` text
M7-A Persistence          PASS
M7-B REST / Service       PASS
M7-C Socket.IO            PASS
M7-D Client/Docs/Regression LOCAL PASS
```

Final local cumulative result:

``` text
scripts/validate_m7.sh
127 passed
0 failed
```

M6 regression remains:

``` text
57 passed
0 failed
```

Current local Alembic head:

``` text
20260813_0004
```

------------------------------------------------------------------------

# 10. Current Domain

``` text
                         GAME
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
    HOME TEAM         AWAY TEAM           SCORE
        │                 │          home_score
        ▼                 ▼          away_score
     PLAYERS           PLAYERS              │
                                              ▼
                                      SCORING EVENTS
```

No separate `game_state` table exists.

No separate Roster table exists.

------------------------------------------------------------------------

# 11. Game Score Architecture

Authoritative current score:

``` text
Game.home_score
Game.away_score
```

Both are persistent PostgreSQL integer fields and begin at zero.

Clients retrieve current score from Game state, not by replaying
ScoringEvents.

Direct score correction is not implemented in M7.

------------------------------------------------------------------------

# 12. ScoringEvent Architecture

Fields:

``` text
id
game_id
team_id
player_id       nullable
event_type
created_at
```

Relationships are represented by scalar foreign keys.

M7 supports only:

``` text
event_type = goal
```

`player_id` may be null.

If supplied, Player must exist and belong to the scoring Team.

------------------------------------------------------------------------

# 13. M7 REST API

Implemented:

``` text
POST /api/scoring-events
GET  /api/games/{game_id}/scoring-events
```

Existing Game retrieval exposes:

``` text
home_score
away_score
```

Scoring history ordering:

``` text
created_at ASC
id ASC
```

Validation:

``` text
Team not participating → 422
Player missing         → 422
Player on wrong Team   → 422
invalid event_type     → 422
Missing Game history   → 404
```

Failed mutations do not alter score or create ScoringEvents.

------------------------------------------------------------------------

# 14. M7 Transaction / Concurrency Architecture

A valid goal uses one transaction:

``` text
Validate
 ↓
Create ScoringEvent
 ↓
Atomic PostgreSQL score increment
 ↓
ONE COMMIT
 ↓
Reload
 ↓
Socket.IO
```

Atomic SQL score increment prevents lost increments under concurrent
accepted requests.

Local concurrency proof:

``` text
10 simultaneous accepted requests
10 successful responses
score delta = 10
ScoringEvent delta = 10
scoring_event:created = 10
game:score_updated = 10
lost increments = 0
lost M7 events = 0
```

------------------------------------------------------------------------

# 15. M7 Socket.IO

New events:

``` text
scoring_event:created
game:score_updated
```

Canonical single-request order:

``` text
COMMIT
 ↓
reload
 ↓
scoring_event:created
 ↓
game:score_updated
```

Failed scoring mutations emit neither M7 event.

Existing M3--M6 events remain operational:

``` text
connection:ready
client:ping
server:pong
test:broadcast
team:created
team:updated
game:created
game:updated
player:created
player:updated
roster:updated
```

`roster:updated` remains invalidation-only:

``` json
{
  "team_id": "<team UUID>"
}
```

------------------------------------------------------------------------

# 16. Alembic State

M6 Player revision:

``` text
20260813_0003
```

M7 score/scoring-event revision:

``` text
20260813_0004
```

Current local result:

``` text
20260813_0004 (head)
```

Do not rewrite existing migrations casually.

------------------------------------------------------------------------

# 17. Validation Assets

Preserve:

``` text
scripts/validate_m6.sh
scripts/validate_m7a.sh
scripts/validate_m7b.sh
scripts/validate_m7c.sh
scripts/validate_m7.sh
```

Current final local M7 result:

``` text
M7 VALIDATION PASSED
Passed: 127
Failed: 0
```

The technical `/client` now displays M7 scoring events in addition to
prior Socket.IO diagnostics.

------------------------------------------------------------------------

# 18. M7 Explicit Deferrals

Do not introduce as part of M7:

``` text
Game clock
Timer persistence
Periods / halves
Halftime
Score correction
Goal deletion
Goal undo
Assists
Cards
Substitutions
Lineups
Statistics
Authentication
Authorization
Users
Organizations
Seasons
Redis
NATS
Kafka
Microservices
Production scoreboard UI
OBS overlay
```

------------------------------------------------------------------------

# 19. Current Review / Deployment Gate

Still required:

``` text
DeepSeek independent review
 ↓
GPT disposition of findings
 ↓
Git commit / push
 ↓
Render deployment
 ↓
Production validate_m7.sh
 ↓
Confirm production Alembic migration
 ↓
Final handoff/map production-state update
 ↓
Commit docs
 ↓
M7 COMPLETE
```

Until those steps finish, do not describe M7 as production complete.

------------------------------------------------------------------------

# 20. Next Planned Milestone

``` text
M8 — Game Clock / Timer Foundation
```

M8 has **not** been architected or authorized.

Do not implement clock, timer, periods, or scoreboard behavior based
only on this directional roadmap.

------------------------------------------------------------------------

# 21. Fresh AI Session Procedure

At the beginning of a new AI conversation:

1.  Read `AI_HANDOFF.md`.
2.  Read `IMPLEMENTATION_MAP.md`.
3.  Read the active milestone specification.
4.  Inspect the actual repository.
5.  Inspect Alembic history.
6.  Reconstruct current architecture before changing code.
7.  Surface conflicts or unresolved architecture questions.
8.  Do not redesign established behavior based on preference.
9.  Work in A/B/C/D checkpoints.
10. Run cumulative regression after each checkpoint.

------------------------------------------------------------------------

# 22. Source-of-Truth Hierarchy

When information conflicts:

``` text
1. Approved architecture decisions
2. Current milestone specification
3. Actual repository
4. Database migrations
5. IMPLEMENTATION_MAP.md
6. Current docs/
7. AI_HANDOFF.md
8. Prior AI chat history
```

------------------------------------------------------------------------

# 23. Current Handoff Summary

``` text
PROJECT
ScoreStreamLive

PRODUCTION COMPLETE
M0–M6

M7 LOCAL STATE
M7-A PASS
M7-B PASS
M7-C PASS
M7-D LOCAL PASS
127/127 cumulative local validation

CURRENT DOMAIN
Game
 ├── Home Team → Players
 ├── Away Team → Players
 ├── home_score
 ├── away_score
 └── ScoringEvents

SOURCE OF TRUTH
PostgreSQL

MUTATION BOUNDARY
REST

REAL-TIME DELIVERY
Socket.IO after commit

ALEMBIC LOCAL HEAD
20260813_0004

M7 FINAL HARNESS
scripts/validate_m7.sh

M6 REGRESSION
57/57 PASS

PENDING
DeepSeek review
GitHub push
Render deployment
Production M7 validation
Final documentation confirmation

NEXT
M8 Game Clock / Timer Foundation — NOT AUTHORIZED YET
```
