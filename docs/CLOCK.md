# ScoreStreamLive — Game Clock / Timer

## Status

```text
MILESTONE 8 COMPLETE
PRODUCTION VALIDATED
```

## Production Evidence

```text
Local M8:
83 / 83 PASS

Production M8:
146 / 146 PASS

Remote M8 clock:
17 / 17 PASS

M7 production regression:
127 / 127 PASS

M6 production regression:
57 / 57 PASS
```

## Core Rule

> The server owns clock truth. Clients render the clock.

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

Alembic:

```text
20260814_0005
```

## Modes

```text
count_up
count_down
```

Count-up may exceed configured duration.

Count-down display clamps at zero.

## Status

```text
stopped
running
paused
```

## Authoritative Time

Stopped/paused:

```text
elapsed = elapsed_seconds
```

Running:

```text
elapsed =
    elapsed_seconds
    +
    floor(server_now - running_since)
```

UTC-aware server timestamps are authoritative.

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

## Optimistic Concurrency

Mutations include:

```text
expected_version
```

Every successful mutation increments `version`.

Stale commands return `409`.

Production validation proved same-version concurrent controllers produce one winner and one stale conflict.

## Socket.IO

Canonical event:

```text
clock:updated
```

It contains committed GameClock state and synchronization metadata.

Failed/stale requests emit no clock update.

There is no:

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

## Restart Recovery

A running clock survives application restart because:

```text
elapsed_seconds
running_since
status
```

are persisted.

Local M8 final validation explicitly restarted the app while the clock was running and proved elapsed time included the restart interval.

## Reconnect Recovery

A reconnecting client fetches current authoritative clock state through REST and resumes local rendering.

No missed tick replay is required.

## Soccer Added Time

For a 45:00 regulation duration:

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

This is elapsed added-time notation.

It is not referee-announced stoppage time.

## Out of Scope

M8 intentionally does not implement:

```text
Pregame
First Half
Halftime
Second Half
Extra Time lifecycle
Final
production Game Controller
production scoreboard
OBS overlay
```
