# ScoreStreamLive — AI Handoff

## Purpose

This file is persistent cross-session project memory for ScoreStreamLive.

**AI chat history is disposable. The repository is authoritative.**

## Current Release

```text
M0–M12 PRODUCTION COMPLETE
M13 IMPLEMENTATION COMPLETE
M13 LOCAL RELEASE GATE — PASS
M13 HUMAN ACCEPTANCE — PASS
M13 PRODUCTION RELEASE GATE — PENDING
```

M13 must not be called fully complete until its final branch is merged to `main`, Render deploys it, production validation passes, merged milestone branches are removed, and `main` is clean.

## Environment

```text
Local:      http://192.168.12.133:8000
Production: https://scorestreamlive.onrender.com
```

Validation modes:

```text
VALIDATION_MODE=local
VALIDATION_MODE=production
```

Production mode must not fail because a Docker-only local recovery action is unavailable.

## Core Architecture

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

Non-negotiable rules:

```text
PostgreSQL = authoritative persistent state
REST       = persistent mutation boundary
Socket.IO  = committed-state notification
```

Successful real-time events describe committed state only.

## Persistent Domains

```text
Game
Team
Player
ScoringEvent
GameClock
GameLifecycle
```

Roster is derived:

```text
Players WHERE player.team_id = team.id
```

There is no Roster table.

## M13 Product Layer

M13 added first-class Team and Roster management around the existing domains and APIs.

Product surfaces:

```text
/teams
/teams/{team_id}
```

M13 capabilities:

```text
Team Management Home
Team create/edit
Team primary/secondary colors
Team logo upload/replacement
Team Detail
Derived roster display
Player create/edit
Roster search/sort and management UX
Responsive/mobile management polish
Persistence/recovery validation
```

M13 did not introduce Player delete or Player transfer. Team membership remains immutable through Player update.

Team logo metadata is persisted on Team (`logo_url`). Image bytes are stored outside PostgreSQL using the existing Team logo storage contract and persistent Docker volume.

## Existing Match Product

```text
/games
/games/{game_id}/setup
/games/{game_id}
/control/games/{game_id}
/overlay/games/{game_id}
```

Scoring, clock, lifecycle, Control Center, Overlay, and pre-game setup architecture remain intact.

## M13 Validation

Canonical release harness:

```text
scripts/validate_m13h.sh
```

Latest local result:

```text
M13-H ............... PASS   36 passed / 0 failed
M13-G cumulative .... PASS
MILESTONE 13 LOCAL RELEASE GATE = PASS
M13-H HUMAN ACCEPTANCE = PASS
```

M13-G locally validates persistence across application and PostgreSQL container restarts. M13-H production mode must skip local-only restart operations while preserving production-safe persistence and cumulative validation.

## Development Workflow

```text
read repository
↓
approve milestone boundaries
↓
chained sub-milestones
↓
automated + cumulative validation
↓
human acceptance
↓
checkpoint each accepted sub-milestone
↓
final local release gate
↓
documentation synchronization
↓
merge final branch → main
↓
production deployment + validation
↓
branch cleanup / clean main
```

Downloaded ZIP/README artifacts are operator transfer artifacts and should be removed before checkpointing unless intentionally part of the repository.

## Deferred Work

See root `BACKLOG.MD`. In particular, validation data has accumulated heavily and requires both a safe test-data cleanup strategy and a deliberate full application-data reset procedure. Do not improvise destructive cleanup.

## Next

After M13 production closure:

```text
M14 — Game Library / Dashboard
```

M14 should make upcoming, live, and completed Games discoverable without redesigning the validated engine.
