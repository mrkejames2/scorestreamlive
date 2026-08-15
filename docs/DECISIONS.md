# ScoreStreamLive — Architecture Decisions

## Current M8 Decisions

### Clock truth

PostgreSQL stores the authoritative GameClock anchor/state.

### Clock rendering

Clients render locally. The server does not broadcast one timer tick per second.

### Modes

Generic modes are:

```text
count_up
count_down
```

### Persistence model

A dedicated `game_clocks` table is used, with one clock maximum per Game.

### Time storage

Store elapsed integer seconds and UTC timestamp anchors, not formatted display strings.

### Count-down

Persist elapsed time; derive remaining display. Clamp displayed remaining time at zero.

### Soccer added time

Derive `+1`, `+2`, etc. from generic elapsed time after the configured regulation threshold.

Do not persist soccer-specific stoppage-time state in the generic GameClock.

### Concurrency

Use optimistic integer `version` and PostgreSQL conditional updates.

Do not use process-local locks as the correctness mechanism.

### Real-time contract

Emit one canonical post-commit:

```text
clock:updated
```

Do not emit:

```text
clock:tick
```

### Reset safety

Reset while running is rejected. Pause first.

### Lifecycle boundary

Game phases/halves are deferred to M9.

### Infrastructure

No Redis, NATS, Kafka, message broker, Socket.IO room requirement, or per-Game background timer is introduced in M8.
