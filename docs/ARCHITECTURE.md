# ScoreStreamLive Architecture

## Release / Development State

```text
M0–M13 PRODUCTION COMPLETE
M14 FEATURE COMPLETE / RELEASE PENDING
M14-0 / M14-A / M14-B / M14-C / M14-D / M14-E COMPLETE
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

## State Ownership

PostgreSQL is authoritative for persistent Game, Team, Player, score, ScoringEvent, GameClock, GameLifecycle, and Team-branding metadata.

REST is the durable mutation boundary.

Socket.IO distributes committed state after successful mutations.

## Current Domain

```text
Game
├── Home Team
│   └── Players (derived roster)
├── Away Team
│   └── Players (derived roster)
├── Score
├── ScoringEvents
├── GameClock
└── GameLifecycle
```

Roster is derived from `Player.team_id`; there is no Roster table.

## Mutation Rule

```text
Validate
↓
Mutate
↓
COMMIT
↓
Reload
↓
Emit
```

## Team / Roster Management Architecture

M13 added a product-management layer around existing Team and Player domains.

Team branding metadata (`logo_url`, primary/secondary colors) remains persistent Team state. Logo image bytes are not stored in PostgreSQL.

Player membership remains represented only by `Player.team_id`.

## Existing Match Architecture

Scoring, clock, lifecycle, Control Center, Overlay, and pre-game setup remain unchanged in architectural responsibility.

GameClock remains timestamp-anchor based with no per-second authoritative DB writes or Socket.IO tick.

Lifecycle remains separate from clock time and uses committed transactional transitions.

## M14 Game Library Architecture

M14 adds discovery/presentation around persisted Game state.

```text
Persisted Game
    │
    ├── Game fields
    ├── GameLifecycle
    └── GameClock
          ↓
Canonical Game Library Classification
          ├── upcoming
          ├── live
          ├── completed
          └── cancelled
          ↓
Game Library Dashboard
          ↓
Search & Filter
          ↓
Bounded Scalable Retrieval
```

Canonical classification is presentation/domain interpretation. It is not a new persistence authority.

M14 must not solve display problems by synchronizing lifecycle state back into `Game.status`.

Protected M14 boundaries:

```text
No new state authority
No lifecycle redesign
No timer redesign
No per-second authoritative tick
No unnecessary database migration
No distributed infrastructure
```

## Product Surfaces

```text
/teams
/teams/{team_id}
/games
/games/{game_id}/setup
/games/{game_id}
/control/games/{game_id}
/overlay/games/{game_id}
```

## Validation Architecture

Active M14+ validation is domain-based.

```text
scripts/validate.sh
      │
      ├── Health
      ├── Web Surfaces
      ├── API Reads
      ├── Architecture
      ├── Game Library
      ├── Game Dashboard
      ├── Game Search/Filter
      ├── Game Retrieval
      ├── Game Clock Configuration
      └── Recovery (release only)
```

Durable current regression protection lives under `scripts/regression/`.

Historical milestone validators remain acceptance records and are not recursively executed by the active orchestrator.

## Infrastructure Not Present

```text
Redis
NATS
Kafka
RabbitMQ
Kubernetes
event sourcing
CQRS
distributed timer service
per-Game timer workers
```

Do not introduce these without explicit architectural approval.

## M14-E Continuous Match Clock

GameClock remains timestamp-anchor based with no per-second database write and no per-second authoritative Socket.IO tick.

Configured half length is `H`.

```text
START_FIRST_HALF:
  elapsed = 0
  regulation threshold = H

START_SECOND_HALF:
  elapsed = H
  regulation threshold = 2H
```

Control Center and Overlay derive added-time presentation from authoritative GameClock state.

During added time, the regulation clock display freezes at the current threshold and `+N` advances.

Lifecycle transitions must derive thresholds from configured `H` and must not restore hard-coded `2700` / `5400` values.
