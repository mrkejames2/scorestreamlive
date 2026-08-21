# ScoreStreamLive — AI Handoff

## Purpose

This file is persistent cross-session project memory for ScoreStreamLive.

**AI chat history is disposable. The repository is authoritative.**

## Current Release / Development State

```text
M0–M13 PRODUCTION COMPLETE

M14-0 — Validation Harness Modernization      COMPLETE
M14-A V2 — Game Library Classification        COMPLETE
M14-B V2 — Game Library Dashboard             COMPLETE
M14-C — Game Library Search & Filter          ACTIVE
M14-C implementation                          NOT STARTED
```

Current M14-C branch:

```text
milestone-14c-game-library-search-filter
```

Current checkpoint before M14-C implementation:

```text
c2427d0 Complete M14-B game library dashboard
```

Important M14 lineage:

```text
0078c3d Modernize validation harness for M14
a4c75ab Complete M14-A game library classification foundation
f4f6955 Integrate M14-A with modern validation harness
c2427d0 Complete M14-B game library dashboard
```

M14-B V2 acceptance:

```text
FAST validation   PASS
FULL validation   PASS
Human acceptance  PASS
```

## Environment

```text
Local:      http://192.168.12.133:8000
Production: https://scorestreamlive.onrender.com
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

## M13 Historical Release Record

M13 delivered first-class Team and Roster management around the existing domains and APIs and is production complete.

Historical M13 acceptance used the milestone-chain validator architecture that existed at that time:

```text
LOCAL:      M13-H 36 passed / 0 failed; M13-G cumulative PASS
HUMAN:      PASS
PRODUCTION: M13-H 36 passed / 0 failed; M13-G cumulative PASS
```

Those historical validators remain acceptance evidence. They are no longer the active regression architecture for new milestones.

## M14 Product Layer

M14 is building Game Library / Dashboard UX around persisted Game state without changing the authoritative match engine.

Current flow:

```text
Persisted Game
    ↓
existing Game / lifecycle / clock reads
    ↓
canonical Game Library classification
    ├─ upcoming
    ├─ live
    ├─ completed
    └─ cancelled
    ↓
Game Library Dashboard
    ↓
M14-C Search & Filter
```

M14-A V2 established canonical classification. M14-B V2 added grouped dashboard presentation and preserved existing launch actions.

Protected M14 boundaries:

```text
No new Game persistence authority
No lifecycle redesign
No Game.status synchronization workaround
No timer redesign
No per-second authoritative tick
No unnecessary database migration
```

## Active Validation Architecture

Current validation entry point:

```text
scripts/validate.sh
```

Durable regression coverage:

```text
scripts/regression/
```

Current domains:

```text
Health
Web Surfaces
API Reads
Architecture
Game Library
Game Dashboard
Recovery        (release scope only)
```

Controls:

```text
VALIDATION_MODE=local|production
VALIDATION_SCOPE=fast|full|release
VALIDATION_OUTPUT=summary|full
VALIDATION_FAIL_FAST=0|1
```

Rules:

- Active domain regressions execute once per run.
- New milestone validators are thin wrappers around the shared harness.
- Historical milestone validators are not recursively replayed.
- Detailed logs are captured during the original run under `.validation/`.
- `full` output reveals captured failure detail without rerunning the suite.
- expensive application/PostgreSQL restart checks belong to `release`.

## Development Workflow

```text
read repository
↓
confirm active milestone boundaries
↓
implement smallest coherent change
↓
FAST domain validation
↓
FULL domain validation at acceptance
↓
human acceptance
↓
checkpoint commit + push
↓
next sub-milestone
```

Use `release` scope for final release/recovery confidence, not ordinary development feedback.

Downloaded ZIP/README/apply artifacts are operator transfer artifacts and should be removed before checkpointing unless intentionally part of the repository.

## Deferred Work

See root `BACKLOG.MD`. Do not improvise destructive cleanup.

## Resume Here

```text
ACTIVE: M14-C — Game Library Search & Filter
IMPLEMENTATION: NOT STARTED
BASELINE: c2427d0
BRANCH: milestone-14c-game-library-search-filter
```

Before implementation:

1. inspect current M14 Game Library code;
2. define M14-C search/filter UX and protected boundaries;
3. add durable M14-C regression coverage to `scripts/regression/`;
4. do not reintroduce recursive historical milestone validation.
