# ScoreStreamLive — Implementation Map

## Release State

```text
M0–M13 PRODUCTION COMPLETE
M14 NOT STARTED
```

M13 production merge: `f9725b0`.

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

### Team

Current Team state includes identity and branding:

```text
id
name
short_name
logo_url
primary_color
secondary_color
created_at
updated_at
```

Logo bytes are deliberately not stored in PostgreSQL. `logo_url` is persistent Team metadata; the logo file uses the existing Team logo storage service/volume contract.

### Player

Player belongs to one Team through `team_id`. M13 exposes create/edit management UI but does not add transfer or delete.

## Product / Web Surfaces

```text
/teams                         Team Management Home
/teams/{team_id}               Team Detail / Roster Management
/games                         Game Management Home
/games/{game_id}/setup         Pre-game setup
/games/{game_id}               Game detail / launch hub
/control/games/{game_id}       Operator Control Center
/overlay/games/{game_id}       Broadcast Overlay
```

### M13 Team Management

`/teams` provides first-class Team discovery and management, including create/edit/branding workflows.

`/teams/{team_id}` provides Team identity/branding plus the derived roster and Player management UX.

The browser continues to use existing REST APIs for persistent mutations:

```text
POST  /api/teams
GET   /api/teams
GET   /api/teams/{team_id}
PATCH /api/teams/{team_id}
POST  /api/teams/{team_id}/logo
GET   /api/teams/{team_id}/players

POST  /api/players
GET   /api/players/{player_id}
PATCH /api/players/{player_id}
```

## Recovery Model

Recovery is authoritative server/database recovery, not browser-state recovery.

M13-G proves locally that Team, Player, Team branding metadata, and Team logo storage survive browser refresh, application-container restart, and PostgreSQL-container restart.

## Validation

Canonical M13 release entry point:

```text
scripts/validate_m13h.sh
```

Accepted M13 release evidence:

```text
LOCAL:      36 passed / 0 failed; M13-G cumulative PASS
HUMAN:      PASS
PRODUCTION: 36 passed / 0 failed; M13-G cumulative PASS
```

M13-G performs local recovery testing; production mode skips Docker-only restart operations.

## Git Model

M13 used chained branches M13-A through M13-H. The final accepted M13-H branch was merged into `main`; production deployment and validation passed. M13 branches may now be removed as release cleanup.

## Next Architectural Layer

```text
M14 — Game Library / Dashboard
STATUS: NOT STARTED
```

M14 should add Game discoverability/dashboard UX around the existing Game domain and lifecycle state without redesigning the engine. Detailed scope requires the M14 startup review.
