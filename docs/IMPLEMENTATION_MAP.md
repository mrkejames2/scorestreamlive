# ScoreStreamLive — Implementation Map

## Release State

```text
M0–M13 PRODUCTION COMPLETE
M14 IN PROGRESS

M14-0 COMPLETE
M14-A V2 COMPLETE
M14-B V2 COMPLETE
M14-C ACTIVE / NOT IMPLEMENTED
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
Docker / Docker Compose
GitHub
Render
HTML / CSS / JavaScript product surfaces
```

## Runtime Architecture

```text
Browser / API Client
        │
   ┌────┴────┐
   │         │
 REST     Socket.IO
   │         │
   └────┬────┘
        │
      FastAPI
        │
      Services
        │
  SQLAlchemy Async
        │
    PostgreSQL
```

PostgreSQL is authoritative. REST performs durable mutations. Socket.IO communicates committed state.

## Persistent Domains

```text
Game
Team
Player
ScoringEvent
GameClock
GameLifecycle
```

Roster has no table. It is derived from `Player.team_id`.

## Product / Web Surfaces

```text
/teams                         Team Management Home
/teams/{team_id}               Team Detail / Roster Management
/games                         Game Library / Dashboard
/games/{game_id}/setup         Pre-game setup
/games/{game_id}               Game detail / launch hub
/control/games/{game_id}       Operator Control Center
/overlay/games/{game_id}       Broadcast Overlay
```

## M14 Game Library Implementation

M14-A V2 introduced the canonical browser classification module:

```text
static/js/games/classification.js
```

Classification outputs:

```text
upcoming
live
completed
cancelled
```

M14-B V2 uses that classification to group `/games` into:

```text
Live Games
Upcoming
Completed
Cancelled
```

The dashboard preserves existing launch behavior:

```text
Open Game
Resume Game
Review Game
Manage Roster
Open Control Center
Open Overlay
```

M14-C will add Search & Filter on top of this accepted layer.

## Validation Implementation

Shared orchestrator:

```text
scripts/validate.sh
```

Shared helpers:

```text
scripts/lib/validation.sh
```

Durable domains:

```text
scripts/regression/health.sh
scripts/regression/surfaces.sh
scripts/regression/api_reads.sh
scripts/regression/architecture.sh
scripts/regression/game_library.sh
scripts/regression/game_dashboard.sh
scripts/regression/recovery.sh
```

Milestone wrappers:

```text
scripts/validate_m14_0.sh
scripts/validate_m14a.sh
scripts/validate_m14b.sh
```

New M14+ milestone wrappers delegate to the shared orchestrator. They must not recursively replay historical milestone validators.

## Recovery Model

Recovery is authoritative server/database recovery, not browser-state recovery.

Expensive application-container and PostgreSQL-container restart checks are isolated to `VALIDATION_SCOPE=release`.

## Current Git Checkpoint

```text
0078c3d Modernize validation harness for M14
a4c75ab Complete M14-A game library classification foundation
f4f6955 Integrate M14-A with modern validation harness
c2427d0 Complete M14-B game library dashboard
```

Current branch:

```text
milestone-14c-game-library-search-filter
```
