# ScoreStreamLive Architecture

## Current Production State

```text
M0–M12 COMPLETE
M12 LOCAL RELEASE GATE — PASS
M12 PRODUCTION RELEASE GATE — PASS
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

PostgreSQL is authoritative for persistent Game, Team, Player, score, ScoringEvent, GameClock, GameLifecycle, and Team-branding state.

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

Roster is derived from Player membership; there is no separate Roster table.

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

Successful real-time events never describe uncommitted state.

## Scoring Architecture

Current score lives on Game. `ScoringEvent` stores history. ScoringEvent creation and Game score mutation occur atomically.

## Clock Architecture

GameClock uses persistent state plus UTC timestamp anchors rather than an in-memory authoritative timer.

A running clock requires no per-second database write, no per-second Socket.IO broadcast, and no timer task per Game.

Clock mutations use optimistic version concurrency.

There is deliberately no authoritative `clock:tick` event.

## Lifecycle Architecture

GameLifecycle owns match meaning; GameClock owns time.

```text
pregame → first_half → halftime → second_half → full_time
```

Integrated lifecycle transitions coordinate lifecycle and clock atomically. Successful lifecycle/clock notifications are emitted only after the shared transaction commits.

## Recovery Architecture

Persisted authoritative state supports:

```text
browser refresh
Socket.IO disconnect/reconnect
returning to a Game later
application-container restart (local recovery validation)
```

M12-G proves that recovery does not depend on previously stored browser state.

## Product Surfaces

M10–M12 added the product-facing layer around the engine:

```text
Control Center
Broadcast Overlay
Game Management Home
Game creation / pre-game setup
Team branding
Roster setup
Game detail / launch hub
Existing-game resume / recovery
```

These surfaces consume the same authoritative domains rather than introducing a separate UI state authority.

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

Adding these requires demonstrated future need and explicit architecture approval.

## Next Architectural Layer

```text
M13 — Team & Roster Management UI
```

M13 is a management/product UX layer around existing Team, Player, roster, branding, REST, Socket.IO, and PostgreSQL architecture. It should not redesign the validated match engine without an explicit architectural requirement.
