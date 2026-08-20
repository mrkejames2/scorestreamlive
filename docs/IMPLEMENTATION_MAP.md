# ScoreStreamLive — Implementation Map

## Current Production Version

```text
M0–M12 COMPLETE
M12 LOCAL + PRODUCTION RELEASE GATES PASS
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
HTML / CSS / JavaScript management and broadcast surfaces
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

PostgreSQL is authoritative. REST is the durable mutation boundary. Socket.IO communicates committed state.

## Persistent Domains

```text
Game
Team
Player
ScoringEvent
GameClock
GameLifecycle
```

Roster has no table; it is derived from Player membership by `team_id`.

### Game

Contains identity/setup fields, Home/Away Team references, authoritative current score, and timestamps.

### Team

Referenced by Games and Players. M12 added persisted branding used by product surfaces, including team colors and logo data/reference according to the implemented storage contract.

### Player

Belongs to one Team through `team_id`; roster membership is derived from this relationship.

### ScoringEvent

Stores scoring history and optional scorer association. Current Game score is updated atomically with scoring-event creation.

### GameClock

One clock per Game. Supports count-up/count-down state, persisted elapsed anchors, optimistic version concurrency, and restart/reconnect recovery.

There is intentionally no `clock:tick` authoritative event.

### GameLifecycle

Persists soccer match phase independently from clock time.

Canonical soccer flow:

```text
pregame → first_half → halftime → second_half → full_time
```

Integrated transitions coordinate lifecycle and clock in one transaction and emit committed state after success.

## Product / Web Surfaces Through M12

```text
/games                         Game Management Home
/games/{game_id}/setup         Pre-game setup / roster management
/games/{game_id}               Game detail / launch hub
/control/games/{game_id}       Operator Control Center
/overlay/games/{game_id}       Broadcast Overlay
```

M12 established a GUI-driven workflow from Team/Game setup through match operation and later recovery.

## Socket.IO Domain Model

Existing domain notifications include Team, Game, Player/Roster, Scoring, Clock, and Lifecycle committed-state changes.

Rules:

```text
validate
↓
mutate database
↓
COMMIT
↓
reload committed state
↓
emit
```

Failed/stale mutations do not emit successful state.

## Recovery Model

Authoritative recovery is server/database based, not browser-state based.

A user can return to Game Management and reopen a persisted Game. Clock/lifecycle/score/rosters/scoring history are recovered from authoritative application state.

Local M12-G validation includes application-container restart recovery. Production M12-H deliberately skips that Docker-only action while validating the deployed end-to-end workflow.

## Validation

Canonical current release entry point:

```text
scripts/validate_m12h.sh
```

Modes:

```text
VALIDATION_MODE=local
VALIDATION_MODE=production
```

Local endpoint:

```text
http://192.168.12.133:8000
```

Production endpoint:

```text
https://scorestreamlive.onrender.com
```

Latest accepted M12-H results:

```text
Local:      35 passed / 0 failed + M12-G cumulative PASS
Production: 35 passed / 0 failed; M12-G SKIPPED as local-only
```

## Development / Git Model

Major milestones use chained sub-milestone branches. Each accepted sub-milestone is checkpointed before the next. The final accepted milestone branch is merged into `main` with a milestone merge commit.

Milestone documentation synchronization is part of closure.

## Next Architectural Layer

```text
M13 — Team & Roster Management UI
```

M13 should add first-class Team/Player/Roster management around the validated domains and APIs without redesigning the match engine.
