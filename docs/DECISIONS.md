# ScoreStreamLive — Architecture Decisions

## Core Decisions

### PostgreSQL Is Authoritative

Persistent business state lives in PostgreSQL.

### REST Is the Persistent Mutation Boundary

Business mutations are performed through REST/service logic.

### Socket.IO Is Committed-State Notification

Successful domain events are emitted after commit.

### Roster Is Derived

No Roster table exists.

### Game Owns Current Score

Game stores `home_score` / `away_score`.

### ScoringEvent Stores Score History

ScoringEvent insert and score increment occur in one transaction.

## Milestone 8 Decisions

### Dedicated GameClock Domain

Use a dedicated `game_clocks` table with one GameClock maximum per Game.

### Generic Clock Modes

```text
count_up
count_down
```

### Generic Clock Status

```text
stopped
running
paused
```

### Store Elapsed Time

Persist elapsed integer seconds.

Count-down is derived from elapsed time rather than storing remaining time.

### UTC Timestamp Anchor

When running, `running_since` anchors elapsed-time reconstruction.

### No Per-Second Database Writes

Running clocks do not update PostgreSQL every second.

### No Per-Second Socket.IO Tick

There is deliberately no `clock:tick`.

### No Per-Game Background Timer

No in-process timer loop is authoritative.

### Optimistic Clock Concurrency

Use integer `version` + `expected_version` and PostgreSQL conditional updates.

### Canonical Clock Event

```text
clock:updated
```

is the single M8 committed clock-state event.

### Reset Safety

Reset while running is rejected. Pause first.

### Soccer Added Time Is Presentation

Derive `+1`, `+2`, etc. from generic elapsed time after the configured regulation duration.

Do not persist soccer-specific stoppage-time fields in GameClock.

### Lifecycle Is Separate

First Half / Halftime / Second Half / Final are not M8 clock-engine state.

They are deferred to Game lifecycle architecture.

### No Premature Distributed Infrastructure

M8 does not introduce:

```text
Redis
NATS
Kafka
RabbitMQ
Kubernetes
distributed timer service
Socket.IO room requirement
```
