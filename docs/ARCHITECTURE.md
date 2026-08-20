# ScoreStreamLive Architecture

## Release State

```text
M0–M12 PRODUCTION COMPLETE
M13 LOCAL/HUMAN ACCEPTED — PRODUCTION RELEASE PENDING
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

M13 adds a product-management layer around existing Team and Player domains.

```text
/teams
/teams/{team_id}
        │
        ▼
existing Team / Player REST APIs
        │
        ▼
services
        │
        ▼
PostgreSQL
```

Team branding metadata (`logo_url`, primary/secondary colors) remains persistent Team state. Logo image bytes are not stored in PostgreSQL; they use the existing Team logo file-storage contract.

Player membership remains represented only by `Player.team_id`. M13 does not add Player transfer or delete.

## Recovery Architecture

Authoritative state supports:

```text
browser refresh
Socket.IO reconnect
returning later
application-container restart
PostgreSQL-container restart
```

M13-G validates Team/Player/branding/logo persistence through local application and database recovery. Recovery does not depend on browser state.

## Existing Match Architecture

Scoring, clock, lifecycle, Control Center, Overlay, and pre-game setup remain unchanged in architectural responsibility.

GameClock remains timestamp-anchor based with no per-second authoritative DB writes or Socket.IO tick.

Lifecycle remains separate from clock time and uses committed transactional transitions.

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

M13 did not introduce new infrastructure.

## Next Architectural Layer

After M13 production closure:

```text
M14 — Game Library / Dashboard
```

M14 should build discovery/dashboard UX around persisted Game state rather than introduce a new source of truth.
