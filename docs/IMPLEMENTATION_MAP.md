# ScoreStreamLive — Implementation Map

## Current Production Version

Milestones 0–7 are complete and production validated.

This file describes what **actually exists now**.

## Runtime Stack

```text
Python
FastAPI
Uvicorn
SQLAlchemy 2.x async
asyncpg
PostgreSQL
Alembic
Pydantic
python-socketio
Docker
Docker Compose
GitHub
Render
```

## Runtime Architecture

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
                          Services
                              │
                              ▼
                       SQLAlchemy Async
                              │
                              ▼
                          PostgreSQL
```

## Startup

```text
Container
 ↓
PostgreSQL available
 ↓
Alembic upgrade head
 ↓
Application starts
 ↓
FastAPI + Socket.IO serve traffic
```

## Persistent Domains

### Game

```text
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

API:

```text
POST   /api/games
GET    /api/games
GET    /api/games/{game_id}
PATCH  /api/games/{game_id}
```

### Team

API:

```text
POST   /api/teams
GET    /api/teams
GET    /api/teams/{team_id}
PATCH  /api/teams/{team_id}
GET    /api/teams/{team_id}/players
```

### Player

```text
id
team_id
first_name
last_name
jersey_number
created_at
updated_at
```

API:

```text
POST   /api/players
GET    /api/players/{player_id}
PATCH  /api/players/{player_id}
```

### Roster

No separate table.

Derived from Player membership.

Ordering:

```text
jersey_number ASC NULLS LAST
last_name ASC
first_name ASC
id ASC
```

### ScoringEvent

```text
id
game_id
team_id
player_id   nullable
event_type
created_at
```

Index:

```text
ix_scoring_events_game_id
```

API:

```text
POST /api/scoring-events
GET  /api/games/{game_id}/scoring-events
```

Ordering:

```text
created_at ASC
id ASC
```

## Scoring Rules

M7 supports:

```text
goal = +1
```

Validation:

```text
Game must exist
Team must participate
Player, if supplied, must exist
Player, if supplied, must belong to scoring Team
event_type must be goal
```

## Atomic Score Mutation

```text
ScoringEvent INSERT
       +
Atomic Game score UPDATE
       ↓
same transaction
       ↓
ONE COMMIT
```

This avoids lost updates under concurrent scoring.

## Socket.IO Events

Technical:

```text
connection:ready
client:ping
server:pong
test:broadcast
```

Game:

```text
game:created
game:updated
game:score_updated
```

Team:

```text
team:created
team:updated
```

Player / roster:

```text
player:created
player:updated
roster:updated
```

Scoring:

```text
scoring_event:created
```

Successful scoring event order:

```text
COMMIT
 ↓
reload
 ↓
scoring_event:created
 ↓
game:score_updated
```

## Migrations

Current production head:

```text
20260813_0004
```

Latest domain revisions:

```text
20260813_0003 — Players
20260813_0004 — Game scores + ScoringEvents
```

## Validation

Final M7 harness:

```text
scripts/validate_m7.sh
```

Production:

```text
127 passed
0 failed
```

M6 regression:

```text
57 passed
0 failed
```

## Static Validation Client

`/client` is a development diagnostic tool that displays:

```text
connection state
ping / acknowledgement
Team events
Game events
Player events
roster updates
scoring events
score updates
disconnect / reconnect
```

It is not the final scoreboard UI.

## Deployment

```text
Ubuntu VM
 ↓
Docker validation
 ↓
Git
 ↓
GitHub
 ↓
Render deploy
 ↓
PostgreSQL migration
 ↓
Production validation
```

## Not Implemented Yet

```text
Game clock
Timer
Periods
Score correction
Production scoreboard projection
OBS overlay
Authentication
Authorization
Organizations
Seasons
```

## Next

```text
M8 — Game Clock / Timer Foundation
```

Not started.
