# ScoreStreamLive Architecture

## Architectural Goal

ScoreStreamLive is being built as a small, reliable real-time sports application appropriate for a one-person development team.

The architecture intentionally avoids distributed complexity until actual requirements justify it.

## Current Production Architecture

```text
                         GAME
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
    HOME TEAM         AWAY TEAM           SCORE
        │                 │          home_score
        ▼                 ▼          away_score
     PLAYERS           PLAYERS              │
                                              ▼
                                      SCORING EVENTS
```

## Application Layers

```text
HTTP / Socket.IO
      ↓
FastAPI / python-socketio
      ↓
Routes
      ↓
Services
      ↓
SQLAlchemy Async
      ↓
PostgreSQL
```

## State Ownership

### PostgreSQL

Authoritative for:

```text
Games
Teams
Players
Game score
ScoringEvents
```

### REST

Authoritative mutation boundary for persistent business state.

### Socket.IO

Notification layer only.

Socket.IO messages communicate state that has already successfully committed.

## Transaction Rule

Never emit a successful domain event for state that failed to persist.

Canonical pattern:

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

## Roster Architecture

Roster is a query, not a domain table:

```text
Players WHERE team_id = Team.id
```

`roster:updated` invalidates client roster state.

Clients refetch through REST.

## Score Architecture

Current score is stored directly on Game:

```text
home_score
away_score
```

There is no separate `game_state` table.

ScoringEvents are history; Game score is current state.

## Scoring Concurrency

Accepted simultaneous goals must not overwrite one another.

M7 uses an atomic PostgreSQL score increment inside the same transaction as the ScoringEvent insert.

Production validation proved 10 simultaneous accepted goals result in:

```text
+10 Game score
+10 ScoringEvents
10 scoring_event:created events
10 game:score_updated events
0 lost increments
```

## Real-Time Architecture

The same application container serves REST and Socket.IO.

No separate event service exists.

Current domain event flow:

```text
POST /api/scoring-events
 ↓
Scoring service
 ↓
PostgreSQL transaction
 ↓
COMMIT
 ↓
scoring_event:created
 ↓
game:score_updated
```

## Deployment Architecture

```text
Developer VM
 ↓
Docker Compose
 ↓
GitHub
 ↓
Render
 ↓
PostgreSQL
```

## Infrastructure Deliberately Not Present

```text
Redis
NATS
Kafka
RabbitMQ
Kubernetes
CQRS
Event sourcing
Distributed Socket.IO
Microservice decomposition
```

Adding these requires an approved milestone need.

## Next Architectural Layer

M8 is expected to introduce Game Clock / Timer behavior.

It must be architected separately.

Do not infer M8 design from M7.
