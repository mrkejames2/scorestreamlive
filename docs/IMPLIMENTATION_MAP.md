# ScoreStreamLive --- IMPLEMENTATION MAP

**Purpose:** Describe the actual current implementation state\
**Production Baseline:** Milestone 6\
**Local Candidate:** Milestone 7 implemented and locally validated\
**Current Domain:** Game → Team → Player + Game Score + ScoringEvent\
**Next Planned Milestone:** M8 --- Game Clock / Timer Foundation, not
yet authorized

> This map distinguishes the production-validated M6 baseline from the
> locally validated M7 candidate. Do not call M7 production-complete
> until Render validation passes.

------------------------------------------------------------------------

# 1. Runtime Stack

``` text
Python
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

------------------------------------------------------------------------

# 2. Runtime Architecture

``` text
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

------------------------------------------------------------------------

# 3. Startup Flow

``` text
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

------------------------------------------------------------------------

# 4. Persistence / Mutation Pattern

Normal domain mutation:

``` text
REST route
    ↓
AsyncSession
    ↓
Service
    ↓
Validation
    ↓
SQLAlchemy / PostgreSQL
    ↓
COMMIT
    ↓
refresh / reload
    ↓
Socket.IO committed-state notification
    ↓
REST response
```

M7 scoring uses a specialized concurrency-safe variant:

``` text
POST /api/scoring-events
    ↓
Scoring Service
    ↓
Validate Game / Team / optional Player
    ↓
Create ScoringEvent
    +
Atomic SQL Game score increment
    ↓
ONE COMMIT
    ↓
Reload committed state
    ↓
scoring_event:created
    ↓
game:score_updated
```

------------------------------------------------------------------------

# 5. Current Domain Model

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

Implemented:

``` text
Game
Team
Player
Derived Team roster
Game score
ScoringEvent
```

Not implemented:

``` text
Game clock
Timer
Periods / halves
Score correction / undo
Scoreboard projection
OBS
Authentication
Authorization
Organizations
Seasons
```

------------------------------------------------------------------------

# 6. Game

Conceptual fields now include:

``` text
id
name
status
scheduled_at
home_team_id
away_team_id
home_score
away_score
created_at
updated_at
```

Game API remains:

``` text
POST   /api/games
GET    /api/games
GET    /api/games/{game_id}
PATCH  /api/games/{game_id}
```

`GET /api/games/{game_id}` exposes authoritative score.

Normal Game PATCH is not the M7 score-mutation path.

------------------------------------------------------------------------

# 7. Team

Conceptual fields:

``` text
id
name
short_name
created_at
updated_at
```

API:

``` text
POST   /api/teams
GET    /api/teams
GET    /api/teams/{team_id}
PATCH  /api/teams/{team_id}
GET    /api/teams/{team_id}/players
```

Games reference Teams as Home and Away Teams.

------------------------------------------------------------------------

# 8. Player

Conceptual fields:

``` text
id
team_id
first_name
last_name
jersey_number
created_at
updated_at
```

Established rules:

``` text
team_id
    required
    immutable in current Player architecture
    FK → teams.id
    ON DELETE RESTRICT

first_name / last_name
    required
    max 255
    trim surrounding whitespace

jersey_number
    nullable integer
    0–999
    duplicates allowed
```

API:

``` text
POST   /api/players
GET    /api/players/{player_id}
PATCH  /api/players/{player_id}
```

No Player DELETE endpoint or transfer system.

------------------------------------------------------------------------

# 9. Roster

No Roster table exists.

Roster is derived from:

``` text
Players WHERE team_id = requested Team
```

Endpoint:

``` text
GET /api/teams/{team_id}/players
```

Ordering:

``` text
jersey_number ASC NULLS LAST
last_name ASC
first_name ASC
id ASC
```

`roster:updated` is an invalidation event, not a full roster payload.

------------------------------------------------------------------------

# 10. Game Score

Persistent authoritative fields:

``` text
games.home_score
games.away_score
```

Properties:

``` text
INTEGER
NOT NULL
default 0
```

Current score is read from Game state.

Clients do not replay ScoringEvents to derive current score.

------------------------------------------------------------------------

# 11. ScoringEvent

Conceptual schema:

``` text
scoring_events
├── id UUID PK
├── game_id UUID NOT NULL FK games.id ON DELETE RESTRICT
├── team_id UUID NOT NULL FK teams.id ON DELETE RESTRICT
├── player_id UUID NULL FK players.id ON DELETE RESTRICT
├── event_type VARCHAR(50) NOT NULL
└── created_at TIMESTAMPTZ NOT NULL
```

Index:

``` text
ix_scoring_events_game_id
```

M7 event type:

``` text
goal
```

`player_id` is nullable.

------------------------------------------------------------------------

# 12. Scoring REST API

``` text
POST /api/scoring-events
GET  /api/games/{game_id}/scoring-events
```

POST success:

``` text
201 Created
```

Scoring validation:

``` text
Game must exist
Team must participate in Game
Player, if supplied, must exist
Player, if supplied, must belong to scoring Team
event_type must be goal
```

History ordering:

``` text
created_at ASC
id ASC
```

------------------------------------------------------------------------

# 13. M7 Atomicity / Concurrency

ScoringEvent persistence and Game score increment use one transaction.

Score increment is an atomic PostgreSQL update rather than a naïve ORM
read/increment/write cycle.

Local concurrency validation:

``` text
Requests:                       10
Successful:                     10
Score delta:                    10
ScoringEvent DB delta:          10
scoring_event:created received: 10
game:score_updated received:    10
Lost increments:                 0
Lost M7 events:                  0
```

------------------------------------------------------------------------

# 14. Socket.IO Foundation

Technical events:

``` text
connection:ready
client:ping
server:pong
test:broadcast
```

Existing domain events:

``` text
game:created
game:updated
team:created
team:updated
player:created
player:updated
roster:updated
```

M7 adds:

``` text
scoring_event:created
game:score_updated
```

All successful domain mutation events represent committed state.

------------------------------------------------------------------------

# 15. M7 Socket.IO Payloads

## scoring_event:created

``` json
{
  "id": "<event UUID>",
  "game_id": "<game UUID>",
  "team_id": "<team UUID>",
  "player_id": "<player UUID or null>",
  "event_type": "goal",
  "created_at": "<ISO timestamp>"
}
```

## game:score_updated

``` json
{
  "game_id": "<game UUID>",
  "home_score": 1,
  "away_score": 0
}
```

Single-request order:

``` text
COMMIT
 ↓
reload
 ↓
scoring_event:created
 ↓
game:score_updated
```

Failed scoring requests emit neither event.

------------------------------------------------------------------------

# 16. Database Migration State

M6:

``` text
20260813_0003
```

M7:

``` text
20260813_0004
```

Current local Alembic:

``` text
20260813_0004 (head)
```

M7 migration adds Game score fields and creates `scoring_events`.

Do not rewrite existing migration history.

------------------------------------------------------------------------

# 17. Validation Harnesses

Preserved:

``` text
scripts/validate_m6.sh
scripts/validate_m7a.sh
scripts/validate_m7b.sh
scripts/validate_m7c.sh
```

Current final M7 harness:

``` text
scripts/validate_m7.sh
```

Latest local result:

``` text
M7 VALIDATION PASSED
Passed: 127
Failed: 0
```

Within that validation:

``` text
M7-C final behavior: 68/68 PASS
M6 regression:        57/57 PASS
```

Current local Alembic:

``` text
20260813_0004 (head)
```

------------------------------------------------------------------------

# 18. Static Validation Client

`/client` is a technical development/diagnostic tool.

It demonstrates:

``` text
connection state
Socket ID
ping / acknowledgement
Team events
Game events
Player events
roster invalidation
scoring_event:created
game:score_updated
disconnect / reconnect
```

It is not the production scoreboard UI.

------------------------------------------------------------------------

# 19. Configuration Rules

Configuration remains centralized.

Do not hardcode:

``` text
Render URL
Database URL
secrets
production CORS values
```

`BASE_URL` is configurable in validation harnesses.

------------------------------------------------------------------------

# 20. Docker

Current local architecture remains:

``` text
Application
PostgreSQL
```

No scoring container or new infrastructure was introduced.

The Docker Compose obsolete `version` warning is non-blocking and
deferred.

------------------------------------------------------------------------

# 21. Render State

Production baseline remains M6 until M7 is pushed and validated.

Known production baseline:

``` text
M6
57/57 PASS
```

M7 production validation is still pending.

Do not state that M7 is deployed until the Render validation is actually
completed.

------------------------------------------------------------------------

# 22. Error Handling

Established pattern remains:

``` text
Pydantic validation → 422
Business validation → controlled route response
Missing resource → 404
Unexpected application/DB failure → existing 500 behavior
```

M7 scoring-specific controlled validation is implemented without
introducing a new global error architecture.

------------------------------------------------------------------------

# 23. Protected Infrastructure

Avoid redesigning without explicit approval:

``` text
Dockerfile
docker-compose.yml
entrypoint/startup
Render configuration
database.py
Alembic configuration/history
Socket.IO initialization
CORS architecture
health endpoints
existing Game API
existing Team API
existing Player API
```

------------------------------------------------------------------------

# 24. Current Application Boundary

Current locally validated application responsibility:

``` text
Game identity
Team identity
Player identity
Roster derivation
Persistent Game score
Persistent ScoringEvent history
Concurrency-safe score mutation
Real-time committed-state notifications
```

Still deferred:

``` text
Clock
Timer
Periods
Score correction
Scoreboard projection
OBS
Authentication
Authorization
Users
Organizations
```

------------------------------------------------------------------------

# 25. Checkpoint Model

The established safe implementation pattern is:

``` text
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
 ↓
Documentation Refresh
```

M6 used this successfully. M7 has now passed A--D locally.

------------------------------------------------------------------------

# 26. Current Completion State

``` text
M0–M6 PRODUCTION COMPLETE

M7-A PASS
M7-B PASS
M7-C PASS
M7-D LOCAL PASS

LOCAL M7
127/127 PASS

LOCAL ALEMBIC
20260813_0004 (head)

PENDING
DeepSeek independent review
GPT disposition
GitHub push
Render deployment
Production M7 validation
Final handoff/map confirmation
```

M7 is therefore **locally complete but not yet production complete**.

------------------------------------------------------------------------

# 27. Next Direction

Planned:

``` text
M8 — Game Clock / Timer Foundation
```

M8 is directional only and not authorized.

Do not implement:

``` text
clock
timer
halves
periods
scoreboard UI
OBS
```

until a dedicated M8 architecture specification is approved.

------------------------------------------------------------------------

# 28. Fresh AI Reconstruction Checklist

Before changing future code, inspect and explain:

``` text
Application startup
Database/session lifecycle
Alembic chain
Game model/schema/service/routes
Team model/schema/service/routes
Player model/schema/service/routes
Roster endpoint
ScoringEvent model/schema/service/routes
Atomic score mutation
Socket.IO initialization
Domain event emissions
Validation harnesses
Docker startup
Render deployment
```

------------------------------------------------------------------------

# 29. Current Summary

``` text
PRODUCTION BASELINE
M6

LOCAL CANDIDATE
M7

DOMAIN
Game
 ├── Home Team → Players
 ├── Away Team → Players
 ├── home_score
 ├── away_score
 └── ScoringEvents

DATABASE
PostgreSQL

REST
Game API
Team API
Player API
Roster endpoint
ScoringEvent create/history endpoints

REAL-TIME
Socket.IO committed-state events

ALEMBIC LOCAL HEAD
20260813_0004

FINAL LOCAL HARNESS
scripts/validate_m7.sh

LOCAL RESULT
127/127 PASS

NEXT GATE
DeepSeek review → GPT decision → GitHub/Render → production validation

NEXT MILESTONE
M8 Game Clock / Timer — not yet authorized
```
