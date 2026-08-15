# ScoreStreamLive — Socket.IO Contracts

## Rule

Socket.IO communicates committed state. PostgreSQL remains authoritative.

## Existing Events

```text
connection:ready
client:ping / acknowledgement
server:pong
test:broadcast

team:created
team:updated

game:created
game:updated
game:score_updated

player:created
player:updated
roster:updated

scoring_event:created
```

## M8 Clock Event

```text
clock:updated
```

Payload:

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

Failed and stale requests emit no clock event.

## No Tick Architecture

There is intentionally no:

```text
clock:tick
```

event.

A client renders locally from the authoritative anchor.

## Version Handling

```text
incoming > local → apply
incoming = local → duplicate/idempotent
incoming < local → ignore stale
```

`game_id` allows clients to isolate the Game they are displaying.

Socket.IO rooms are not required by M8.
