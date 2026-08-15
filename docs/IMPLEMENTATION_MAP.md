# ScoreStreamLive — Implementation Map

## Production Baseline

```text
M0–M7 production complete
```

## Local Candidate

```text
M8-A PASS
M8-B PASS
M8-C PASS
M8-D IN PROGRESS
```

## Stack

```text
FastAPI
python-socketio
SQLAlchemy async
asyncpg
PostgreSQL
Alembic
Pydantic
Docker Compose
GitHub
Render
```

## Domain

```text
Game
├── home_team_id / away_team_id
├── home_score / away_score
├── ScoringEvents
└── GameClock

Team
└── Players

Roster
└── derived from Players by team_id
```

## GameClock Persistence

```text
game_clocks
├── id UUID
├── game_id UUID UNIQUE FK games.id RESTRICT
├── mode
├── status
├── duration_seconds
├── elapsed_seconds
├── running_since TIMESTAMPTZ NULL
├── version
├── created_at
└── updated_at
```

Alembic:

```text
20260814_0005
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

## Clock Concurrency

Mutations include `expected_version`.

Database update conditions include current version/state.

Stale mutations return `409` and do not overwrite committed state.

## Real-Time

```text
clock:updated
```

contains a full committed snapshot and synchronization metadata.

No per-second `clock:tick`.

## Rendering

Running clients calculate locally:

```text
elapsed_seconds + (estimated_server_now - running_since)
```

Count-down derives:

```text
max(duration_seconds - authoritative_elapsed, 0)
```

## Validation Assets

```text
scripts/validate_m8a.sh
scripts/validate_m8b.sh
scripts/validate_m8c.sh
scripts/validate_m8.sh
```

Current checkpoint results:

```text
M8-A 44/44 PASS
M8-B 79/79 PASS
M8-C 75/75 PASS
```

## Scope Not Yet Implemented

```text
Game phases / halves
production control UI
public scoreboard UI
OBS overlay
authentication
organizations
```
