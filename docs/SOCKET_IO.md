# ScoreStreamLive — Socket.IO

## Purpose

Socket.IO delivers real-time notifications for committed application state.

It is **not** the source of truth.

PostgreSQL remains authoritative.

## Architecture

The FastAPI application and Socket.IO server run in the same application service.

## Technical Events

```text
connection:ready
client:ping
server:pong
test:broadcast
```

## Team Events

```text
team:created
team:updated
```

## Game Events

```text
game:created
game:updated
game:score_updated
```

## Player / Roster Events

```text
player:created
player:updated
roster:updated
```

`roster:updated` is invalidation-only:

```json
{
  "team_id": "<team UUID>"
}
```

## Scoring Event

```text
scoring_event:created
```

Payload:

```json
{
  "id": "<event UUID>",
  "game_id": "<game UUID>",
  "team_id": "<team UUID>",
  "player_id": "<player UUID or null>",
  "event_type": "goal",
  "created_at": "<ISO timestamp>"
}
```

## Score Update

```text
game:score_updated
```

Payload:

```json
{
  "game_id": "<game UUID>",
  "home_score": 1,
  "away_score": 0
}
```

## Scoring Event Ordering

For one successful scoring mutation:

```text
COMMIT
 ↓
reload committed state
 ↓
scoring_event:created
 ↓
game:score_updated
```

Both new events must be emitted using awaited async Socket.IO calls.

## Failed Mutations

Validation or persistence failures must emit neither:

```text
scoring_event:created
game:score_updated
```

## Concurrent Scoring

Across simultaneous requests, final database state and event counts are guaranteed.

Intermediate score-update messages are not required to arrive in globally monotonic order.

## Validation Client

```text
/client
```

is a technical diagnostic page showing:

```text
connection lifecycle
ping / ack
Team events
Game events
Player events
Roster invalidation
Scoring events
Score updates
disconnect / reconnect
```

It is not the production scoreboard.
