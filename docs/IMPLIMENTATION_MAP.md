# ScoreStreamLive — IMPLEMENTATION MAP

**Purpose:** Describe the actual currently deployed architecture  
**Current Production Milestone:** 6  
**Current Domain:** Game → Team → Player  
**Next Planned Milestone:** 7 — Game State / Scoring Foundation

---

# 1. Purpose

This file describes what exists now and how it works.

A milestone specification describes what we intend to build. This file describes the deployed implementation.

Fresh AI sessions should read this file together with:

```text
AI_HANDOFF.md
Current MILESTONE_X.md
Repository
```

---

# 2. Runtime Stack

Current stack:

```text
Python 3.13
FastAPI
SQLAlchemy 2.x async
asyncpg
PostgreSQL
Alembic
Pydantic v2
python-socketio
Uvicorn
Docker
Docker Compose
GitHub
Render
```

The repository is authoritative for exact versions.

---

# 3. Runtime Architecture

```text
                       Browser / API Client
                              │
                ┌─────────────┴─────────────┐
                │                           │
              REST                      Socket.IO
                │                           │
                ▼                           ▼
             FastAPI                python-socketio
                │                           │
                └─────────────┬─────────────┘
                              ▼
                        Application
                              │
                              ▼
                           Services
                              │
                              ▼
                       SQLAlchemy Async
                              │
                              ▼
                          PostgreSQL
```

---

# 4. Startup Flow

```text
Docker / Render
      ↓
PostgreSQL available
      ↓
Alembic upgrade head
      ↓
Uvicorn
      ↓
FastAPI + Socket.IO ASGI app
```

Migrations run before serving traffic.

---

# 5. Persistence Pattern

```text
FastAPI route
    ↓
AsyncSession dependency
    ↓
Service
    ↓
SQLAlchemy
    ↓
PostgreSQL
```

Commits happen in services.

Mutation pattern:

```text
Validate
 ↓
Create / modify ORM entity
 ↓
db.commit()
 ↓
refresh / reload
 ↓
Socket.IO domain event
 ↓
response
```

---

# 6. Domain Model

Current production domain:

```text
                         GAME
                          │
          ┌───────────────┴───────────────┐
          ▼                               ▼
      HOME TEAM                       AWAY TEAM
          │                               │
          ▼                               ▼
       PLAYERS                          PLAYERS
```

Implemented:
- Game
- Team
- Player

Not yet implemented:
- Game State
- Score
- Goal / scoring event
- Clock
- Scoreboard
- Authentication
- Organization
- Season

---

# 7. Game

Conceptually:

```text
id
name
status
scheduled_at
home_team_id
away_team_id
created_at
updated_at
```

Current API:

```text
POST   /api/games
GET    /api/games
GET    /api/games/{game_id}
PATCH  /api/games/{game_id}
```

---

# 8. Team

Conceptually:

```text
id
name
short_name
created_at
updated_at
```

Current API:

```text
POST   /api/teams
GET    /api/teams
GET    /api/teams/{team_id}
PATCH  /api/teams/{team_id}
GET    /api/teams/{team_id}/players
```

Games reference Teams.

---

# 9. Player

Conceptually:

```text
id
team_id
first_name
last_name
jersey_number
created_at
updated_at
```

Rules:

```text
team_id
    required
    immutable in M6
    FK → teams.id
    ON DELETE RESTRICT

first_name / last_name
    required
    max 255
    trim surrounding whitespace

jersey_number
    nullable integer
    0–999
    not unique
```

Current API:

```text
POST   /api/players
GET    /api/players/{player_id}
PATCH  /api/players/{player_id}
```

No Player DELETE endpoint. No Player transfer system.

---

# 10. Roster

No separate Roster table exists.

Roster is derived from:

```text
Players WHERE team_id = requested Team
```

Endpoint:

```text
GET /api/teams/{team_id}/players
```

Behavior:

```text
Missing Team → 404
Existing Team, no Players → []
Existing Team, Players → ordered list
```

Ordering:

```text
jersey_number ASC NULLS LAST
last_name ASC
first_name ASC
id ASC
```

---

# 11. Socket.IO Foundation

Technical events from M3 include:

```text
connection:ready
client:ping
server:pong
test:broadcast
```

Connect/disconnect/reconnect behavior remains part of regression validation.

---

# 12. Domain Events

Game:

```text
game:created
game:updated
```

Team:

```text
team:created
team:updated
```

Player:

```text
player:created
player:updated
roster:updated
```

All domain mutation events are emitted after successful commit.

---

# 13. Player Event Payload

```json
{
  "id": "<player UUID>",
  "team_id": "<team UUID>",
  "first_name": "...",
  "last_name": "...",
  "jersey_number": 13,
  "created_at": "...",
  "updated_at": "..."
}
```

---

# 14. Player Event Ordering

Creation:

```text
COMMIT
 ↓
REFRESH
 ↓
player:created
 ↓
roster:updated
```

Update:

```text
COMMIT
 ↓
REFRESH
 ↓
player:updated
 ↓
roster:updated
```

Failed mutations do not emit successful-state events.

---

# 15. roster:updated

Invalidation-only event:

```json
{
  "team_id": "<team UUID>"
}
```

Authoritative roster is retrieved through:

```text
GET /api/teams/{team_id}/players
```

This is an intentional architecture decision.

---

# 16. Database Migration State

Current Player migration:

```text
alembic/versions/20260813_0003_create_players_table.py
```

Revision:

```text
20260813_0003
```

Schema conceptually:

```text
players
├── id UUID PK
├── team_id UUID NOT NULL FK teams.id ON DELETE RESTRICT
├── first_name VARCHAR(255) NOT NULL
├── last_name VARCHAR(255) NOT NULL
├── jersey_number INTEGER NULL
├── created_at TIMESTAMPTZ NOT NULL
└── updated_at TIMESTAMPTZ NOT NULL
```

Index:

```text
ix_players_team_id
```

No jersey uniqueness constraint.

---

# 17. Validation Harness

Current reusable regression harness:

```text
scripts/validate_m6.sh
```

Final M6 results:

```text
LOCAL
57 passed
0 failed

RENDER PRODUCTION
57 passed
0 failed
```

Coverage includes:

- health
- Game
- Team
- Player
- roster
- ordering
- Team isolation
- validation errors
- Socket.IO
- payloads
- event ordering
- failed mutation suppression
- reconnect

Preserve and extend this pattern in future milestones.

---

# 18. Static Validation Client

The browser validation client is a technical development tool.

It demonstrates:
- connection status
- Socket ID
- ping / ack
- Game events
- Team events
- Player events
- roster invalidation
- disconnect/reconnect

It is not the production scoreboard UI.

---

# 19. Configuration Rules

Configuration remains centralized.

Do not hardcode:
- Render URL
- Database URL
- secrets
- production CORS values

---

# 20. Docker

Current local architecture remains intentionally small:

```text
Application
PostgreSQL
```

No extra infrastructure is currently required.

The Docker Compose obsolete `version` warning is non-blocking and deferred.

---

# 21. Render

Render hosts the application.

Production currently supports:
- REST
- Socket.IO
- PostgreSQL-backed domain state

M6 production validation succeeded.

---

# 22. Error Handling

Current established pattern:

```text
Pydantic validation → 422
Business validation → controlled route response
Missing resource → 404
Unexpected application/DB failure → existing 500 behavior
```

Do not introduce a new error architecture inside an unrelated milestone.

---

# 23. Protected Infrastructure

Future milestones should avoid redesigning without explicit architecture approval:

```text
Dockerfile
docker-compose.yml
entrypoint/startup path
Render configuration
database.py
Alembic configuration
Socket.IO initialization
CORS architecture
health endpoints
Game API
Team API
Player API
existing validation harness
```

---

# 24. Current Boundary

Current application responsibility:

```text
Game identity
Team identity
Player identity
Roster derivation
Persistent state
Real-time domain notifications
```

Not yet implemented:

```text
Live game state
Score
Scoring events
Clock
Scoreboard projection
OBS
Authentication
Authorization
Users
Organizations
```

---

# 25. Expected M7 Direction

Directional only:

```text
Game
 ↓
Game State
 ↓
Score
 ↓
Scoring Events
```

Possible future shape:

```text
                         GAME
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
    HOME TEAM         AWAY TEAM         GAME STATE
        │                 │                 │
        ▼                 ▼             ┌───┴───┐
     PLAYERS           PLAYERS          ▼       ▼
                                      SCORE   EVENTS
```

M7 architecture must be formally defined before implementation.

---

# 26. Fresh AI Reconstruction Checklist

Before coding, a fresh AI should inspect and explain:

```text
Application startup
Database/session lifecycle
Alembic chain
Game model/schema/service/routes
Team model/schema/service/routes
Player model/schema/service/routes
Roster endpoint
Socket.IO initialization
Domain event emissions
Validation harness
Docker startup
Render deployment
```

---

# 27. Change Classification Rule

Before implementing a milestone, classify proposed changes as:

```text
NEW FILES
SMALL MODIFICATIONS
PROTECTED / SHOULD NOT CHANGE
```

If a milestone unexpectedly requires broad changes to protected infrastructure, stop for architecture review.

---

# 28. Checkpoint Rule

Future milestones should use checkpoints:

```text
A — Persistence
 ↓ validate

B — REST / Service
 ↓ validate

C — Socket.IO
 ↓ validate

D — Client / Docs / Regression
 ↓ validate

Independent Review
 ↓
Production
```

This checkpoint model was successfully used to complete M6 safely.

---

# 29. Mandatory Documentation Refresh

Before starting the next milestone:

```text
AI_HANDOFF.md
IMPLEMENTATION_MAP.md
```

must be updated to reflect the completed production state.

This is now a permanent project requirement.

---

# 30. Current Production Summary

```text
CURRENT MILESTONE
6 COMPLETE

DOMAIN
Game
 ↓
Team
 ↓
Player

DATABASE
PostgreSQL

REST
Game API
Team API
Player API
Team roster endpoint

REAL-TIME
Socket.IO

VALIDATION
scripts/validate_m6.sh

LOCAL
57/57 PASS

PRODUCTION
57/57 PASS

NEXT
M7 Game State / Scoring Foundation
```

This implementation map must describe actual deployed behavior, not future wishes.
