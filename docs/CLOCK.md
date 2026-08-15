# ScoreStreamLive — Game Clock / Timer

## Status

Milestone 8 implementation is locally validated through M8-C.

M8-D final validation, independent review, Render deployment, and production validation remain the completion gates.

## Core Rule

> The server owns clock truth. Clients render the clock.

ScoreStreamLive does not send one Socket.IO tick every second.

A running clock is represented by persisted state plus an authoritative timestamp anchor.

## Persistence

`game_clocks`:

```text
id
game_id
mode
status
duration_seconds
elapsed_seconds
running_since
version
created_at
updated_at
```

One Game has at most one GameClock.

Current migration:

```text
20260814_0005
```

## Modes

```text
count_up
count_down
```

Count-up may continue beyond the configured duration.

Count-down display clamps at zero.

## Status

```text
stopped
running
paused
```

## Authoritative Elapsed Time

When stopped/paused:

```text
elapsed = elapsed_seconds
```

When running:

```text
elapsed =
    elapsed_seconds
    +
    floor(server_now - running_since)
```

Clock arithmetic uses UTC-aware server timestamps.

## REST

```text
POST  /api/games/{game_id}/clock
GET   /api/games/{game_id}/clock
PATCH /api/games/{game_id}/clock

POST /api/games/{game_id}/clock/start
POST /api/games/{game_id}/clock/pause
POST /api/games/{game_id}/clock/resume
POST /api/games/{game_id}/clock/reset
```

Mutations use `expected_version`.

Stale controllers receive `409 Conflict`.

## Optimistic Concurrency

Every successful mutation increments:

```text
version += 1
```

Same-version simultaneous commands cannot both commit.

PostgreSQL conditional updates provide correctness.

## Socket.IO

Canonical event:

```text
clock:updated
```

It is emitted only after successful commit and reload.

There is deliberately no:

```text
clock:tick
```

## Client Rendering

Clients use:

```text
elapsed_seconds
running_since
server_time
mode
duration_seconds
version
```

to render locally.

Incoming events older than local version should be ignored.

## Soccer Added Time

For a count-up clock with 45:00 target:

```text
44:59       normal
45:00–45:59 +1
46:00–46:59 +2
47:00–47:59 +3
```

Derived:

```text
floor((elapsed - duration) / 60) + 1
```

This is elapsed added-time presentation, not referee-announced stoppage time.

## Restart Safety

No in-memory timer loop is authoritative.

If the application restarts while a clock is running, persisted:

```text
elapsed_seconds
running_since
status
```

are sufficient to reconstruct current time.

## Scope Boundary

M8 does not implement:

```text
first half
halftime
second half
extra time lifecycle
announced stoppage time
production game controller
scoreboard overlay
```

Those belong to later milestones.
