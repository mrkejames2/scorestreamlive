# ScoreStreamLive — Socket.IO

## Rule

Socket.IO communicates committed state.

PostgreSQL remains authoritative.

## Technical Events

```text
connection:ready
client:ping
server:pong
test:broadcast
```

## Team

```text
team:created
team:updated
```

## Game

```text
game:created
game:updated
game:score_updated
```

## Player / Roster

```text
player:created
player:updated
roster:updated
```

## Scoring

```text
scoring_event:created
```

## Clock

```text
clock:updated
```

Conceptual payload:

```json
{
  "id": "<clock UUID>",
  "game_id": "<game UUID>",
  "mode": "count_up",
  "status": "running",
  "duration_seconds": 2700,
  "elapsed_seconds": 1200,
  "running_since": "<ISO timestamp or null>",
  "version": 9,
  "created_at": "<ISO timestamp>",
  "updated_at": "<ISO timestamp>",
  "server_time": "<ISO timestamp>",
  "authoritative_elapsed_seconds": 1234,
  "display_seconds": 1234
}
```

Emitted after committed:

```text
clock creation
configuration
start
pause
resume
reset
```

Failed and stale requests emit no clock update.

## No Tick Architecture

There is intentionally no:

```text
clock:tick
```

Clients render locally.

## Version Handling

Clients should prefer newer versions:

```text
incoming > local → apply
incoming = local → duplicate/idempotent
incoming < local → ignore stale
```

## Multi-Game

Every clock event contains `game_id`.

M8 does not require Socket.IO rooms.
