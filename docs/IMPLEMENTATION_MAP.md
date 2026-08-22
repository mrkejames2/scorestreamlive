# ScoreStreamLive — Implementation Map

## Release State

```text
M0–M13 PRODUCTION COMPLETE
M14 FEATURE COMPLETE / RELEASE PENDING

M14-0 COMPLETE
M14-A V2 COMPLETE
M14-B V2 COMPLETE
M14-C COMPLETE
M14-D COMPLETE
M14-E COMPLETE
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

M14-C added Search & Filter on top of this accepted layer.

M14-D added bounded/scalable Game retrieval and lazy Team loading.

M14-E added configurable continuous soccer match timing and synchronized added-time presentation in the Control Center and Overlay.

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
scripts/regression/game_search_filter.sh
scripts/regression/game_retrieval.sh
scripts/regression/game_clock_configuration.sh
scripts/regression/recovery.sh
```

Milestone wrappers:

```text
scripts/validate_m14_0.sh
scripts/validate_m14a.sh
scripts/validate_m14b.sh
scripts/validate_m14c.sh
scripts/validate_m14d.sh
scripts/validate_m14e.sh
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
821dcc1 Complete M14-C game library search and filter
04c8620 Add local development data reset and M14 demo seed
55f8045 Complete M14-D scalable game library retrieval
ca64d9f Complete M14-E configurable continuous match clock
```

Current branch:

```text
milestone-14e-clock-duration-configuration
```

## M14-E Clock Implementation

Key files:

```text
app/services/game_lifecycle_service.py
static/js/control/api.js
static/js/control/clock.js
static/js/control/control.js
templates/control/game.html
static/css/control-m14e.css
static/js/overlay/overlay.js
templates/overlay/game.html
static/css/overlay-m14e.css
scripts/regression/game_clock_configuration.sh
scripts/validate_m14e.sh
```

Continuous semantics:

```text
H = configured half duration
first-half threshold = H
second-half elapsed start = H
full-match threshold = 2H
```
