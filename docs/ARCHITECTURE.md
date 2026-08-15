# ScoreStreamLive Architecture

## Current Production State

```text
M0–M8 COMPLETE
M8 PRODUCTION VALIDATED
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

PostgreSQL is authoritative for:

```text
Games
Teams
Players
Game score
ScoringEvents
GameClocks
```

REST is the durable mutation boundary.

Socket.IO distributes committed state.

## Current Domain

```text
Game
├── Home Team
│   └── Players
├── Away Team
│   └── Players
├── Score
├── ScoringEvents
└── GameClock
```

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

Current score lives on Game.

ScoringEvent stores history.

ScoringEvent insert and Game score increment occur in one transaction.

## Clock Architecture

GameClock is represented as:

```text
persistent state
+
UTC timestamp anchor
```

not as an in-memory background timer.

When running:

```text
current elapsed =
    elapsed_seconds
    +
    floor(server_now - running_since)
```

Clients render locally from the same authoritative anchor.

## Clock Scale Model

A running clock requires:

```text
no per-second database write
no per-second Socket.IO broadcast
no timer task per Game
```

This allows many simultaneous running Games without one continuous server loop per Game.

## Concurrency

Clock state carries integer `version`.

Mutations provide `expected_version`.

PostgreSQL conditional updates decide the winner.

## Real-Time Clock Contract

```text
clock:updated
```

is emitted only after commit.

There is deliberately no:

```text
clock:tick
```

## Restart Safety

Persisted clock anchors allow current time to be reconstructed after application restart.

This behavior is locally validated.

## Soccer Presentation

Generic GameClock persists no soccer-specific phase or stoppage-time columns.

Soccer added-time minute is derived from generic elapsed time after the configured regulation duration.

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

Adding these requires a demonstrated future need.

## Next Architectural Layer

Directional:

```text
M9 — Game Lifecycle / Phases
```

Not started.
