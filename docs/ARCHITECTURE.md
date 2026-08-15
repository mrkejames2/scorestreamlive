# ScoreStreamLive Architecture

## Current Candidate State

```text
M0–M7 COMPLETE / PRODUCTION VALIDATED
M8-A PASS
M8-B PASS
M8-C PASS
M8-D IN PROGRESS
```

M8 production validation is not yet complete.

## Runtime

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

## State Ownership

PostgreSQL owns durable state:

```text
Games
Teams
Players
Scores
ScoringEvents
GameClocks
```

REST is the persistent mutation boundary.

Socket.IO distributes committed state.

## Current Domain

```text
Game
├── Home Team
│   └── Players
├── Away Team
│   └── Players
├── home_score
├── away_score
├── ScoringEvents
└── GameClock
```

## Mutation Rule

```text
Validate
 ↓
database mutation
 ↓
COMMIT
 ↓
reload
 ↓
Socket.IO notification
```

A successful event must never describe uncommitted state.

## Clock Architecture

The GameClock is `state + time`, not a background timer process.

```text
elapsed_seconds
+
running_since
+
server_time
=
current authoritative elapsed time
```

Clients render the clock locally.

The server emits `clock:updated` only on committed state/configuration transitions.

There is no per-second `clock:tick`.

## Concurrency

GameClock commands use optimistic `version` control and conditional PostgreSQL updates.

Two controllers using the same version cannot both overwrite state.

## Scale Boundary

No timer task is created per Game.

Many simultaneous running Games therefore do not require one continuous server loop or one database write every second.

## Deferred

```text
Game lifecycle/phases
Production control UI
Production scoreboard
OBS
Authentication
Organizations
Distributed messaging infrastructure
```
