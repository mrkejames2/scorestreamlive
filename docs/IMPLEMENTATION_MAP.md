# ScoreStreamLive — Implementation Map

## Current Production Version

```text
M0–M8 COMPLETE
M8 PRODUCTION VALIDATED
```

## Latest Checkpoint

```text
Implementation commit:
ecbd6ab

Alembic:
20260814_0005
```

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
                └─────────────┬─────────────┘
                              ▼
                          FastAPI
                              │
                           Services
                              │
                       SQLAlchemy Async
                              │
                          PostgreSQL
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

### Team

Games reference Teams through home/away IDs.

### Player

Players belong to Teams via `team_id`.

### Roster

No table.

Derived by Team membership.

### ScoringEvent

```text
id
game_id
team_id
player_id nullable
event_type
created_at
```

### GameClock

```text
id
game_id UNIQUE
mode
status
duration_seconds
elapsed_seconds
running_since
version
created_at
updated_at
```

## GameClock REST

```text
POST  /api/games/{game_id}/clock
GET   /api/games/{game_id}/clock
PATCH /api/games/{game_id}/clock

POST /api/games/{game_id}/clock/start
POST /api/games/{game_id}/clock/pause
POST /api/games/{game_id}/clock/resume
POST /api/games/{game_id}/clock/reset
```

## Clock Calculation

Running:

```text
elapsed =
    elapsed_seconds
    +
    floor(server_now - running_since)
```

Count up:

```text
display = elapsed
```

Count down:

```text
display =
    max(duration_seconds - elapsed, 0)
```

## Concurrency

Clock mutations require `expected_version`.

PostgreSQL conditional updates ensure stale same-version commands cannot both commit.

## Socket.IO

Technical:

```text
connection:ready
client:ping
server:pong
test:broadcast
```

Domain:

```text
team:created
team:updated

game:created
game:updated
game:score_updated

player:created
player:updated
roster:updated

scoring_event:created

clock:updated
```

There is no:

```text
clock:tick
```

## Clock Event Model

Successful clock mutation:

```text
validate
↓
database mutation
↓
COMMIT
↓
reload committed clock
↓
clock:updated
```

## Restart Safety

No background timer is authoritative.

Persisted:

```text
elapsed_seconds
running_since
status
```

allow a running clock to survive application restart.

## Validation

```text
M8 local:      83 / 83 PASS
M8 production: 146 / 146 PASS
M8 remote:      17 / 17 PASS
M7 production: 127 / 127 PASS
M6 production:  57 / 57 PASS
```

## Technical Validation Client

`/client` supports manual M8 diagnostics:

```text
clock creation
mode/duration
start
pause
resume
reset
version
server_time
running_since
rendered time
soccer added-time display
clock:updated logging
disconnect/reconnect
```

It is not the production game controller.

## Deployment

```text
Ubuntu VM
↓
Docker validation
↓
GitHub
↓
Render
↓
Alembic
↓
production validation
```

## Next

```text
M9 NOT STARTED
```
