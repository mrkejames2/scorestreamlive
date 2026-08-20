# ScoreStreamLive — AI Handoff

## Purpose

This file is persistent cross-session project memory for ScoreStreamLive.

**AI chat history is disposable. The repository is authoritative.**

## Current Release

```text
M0–M13 PRODUCTION COMPLETE
M13 LOCAL RELEASE GATE — PASS
M13 HUMAN ACCEPTANCE — PASS
M13 PRODUCTION RELEASE GATE — PASS
```

M13 was merged to `main` at merge commit `f9725b0`, deployed through Render, and passed the production M13-H release harness with 36 passed / 0 failed plus M13-G cumulative PASS.

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

Roster is derived from Players where `player.team_id = team.id`; there is no Roster table.

## M13 Product Layer

M13 added first-class Team and Roster management around the existing domains and APIs.

```text
/teams
/teams/{team_id}
```

Capabilities include Team create/edit/branding, logo upload/replacement, Team Detail, derived roster display, Player create/edit, roster search/sort/management UX, responsive/mobile polish, and persistence/recovery validation.

M13 did not introduce Player delete or Player transfer. Team membership remains immutable through Player update.

Team logo metadata is persisted on Team (`logo_url`). Image bytes remain outside PostgreSQL under the existing Team logo storage contract.

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

Accepted release evidence:

```text
LOCAL:      M13-H 36 passed / 0 failed; M13-G cumulative PASS
HUMAN:      PASS
PRODUCTION: M13-H 36 passed / 0 failed; M13-G cumulative PASS
```

M13-G locally validates persistence across application and PostgreSQL container restarts. Production mode skips local-only restart operations while preserving production-safe cumulative validation.

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

See root `BACKLOG.MD`. Validation data has accumulated heavily and requires both a safe test-data cleanup strategy and a deliberate full application-data reset procedure. `/teams` discoverability for large datasets is also deferred. Do not improvise destructive cleanup.

## Next

```text
M14 — Game Library / Dashboard
STATUS: NOT STARTED
```

M14 should make upcoming, live, and completed Games discoverable without redesigning the validated engine. Start M14 only after a fresh repository inspection and approved milestone plan.
