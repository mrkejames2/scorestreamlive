# ScoreStreamLive — Scoring Domain

## Status

Introduced in Milestone 7 and production validated.

## Current Score

Authoritative current score belongs to Game:

```text
home_score
away_score
```

New Games begin:

```text
0 - 0
```

## ScoringEvent

Fields:

```text
id
game_id
team_id
player_id
event_type
created_at
```

`player_id` is nullable.

## Supported Event Type

```text
goal
```

One accepted goal increments the scoring Team by one.

## Create Scoring Event

```text
POST /api/scoring-events
```

Conceptual request:

```json
{
  "game_id": "<game UUID>",
  "team_id": "<team UUID>",
  "player_id": "<player UUID or null>",
  "event_type": "goal"
}
```

Success:

```text
201 Created
```

## Validation

Team must be one of the Game's participating Teams.

If a Player is supplied:

```text
Player must exist
Player.team_id must equal scoring team_id
```

Null Player is allowed.

## Transaction

```text
Create ScoringEvent
        +
Atomic score increment
        ↓
ONE transaction
        ↓
COMMIT
```

The service must not independently commit event and score.

## Concurrency

Score increment uses an atomic SQL update rather than:

```text
read score
increment Python value
write score
```

Production validation proved no lost increments across 10 simultaneous accepted goals.

## History

```text
GET /api/games/{game_id}/scoring-events
```

Ordering:

```text
created_at ASC
id ASC
```

## Socket.IO

Successful committed scoring emits:

```text
scoring_event:created
game:score_updated
```

Order:

```text
scoring_event:created
 ↓
game:score_updated
```

Failed scoring requests emit neither.

## Not Implemented

```text
goal undo
goal deletion
manual score override
score decrement
own-goal-specific domain behavior
assists
cards
substitutions
statistics
```

These require future milestone design.
