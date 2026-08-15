# ScoreStreamLive — Game Domain

## Status

Production validated through Milestone 7.

## Game State

Current fields conceptually include:

```text
id
name
status
scheduled_at
home_team_id
away_team_id
home_score
away_score
created_at
updated_at
```

## Team Relationships

A Game can reference:

```text
home_team_id
away_team_id
```

Both point to Team records.

## Score

Game owns the authoritative current score:

```text
home_score
away_score
```

New Games begin `0–0`.

Clients retrieve current score from Game REST state.

ScoringEvent history is not replayed to calculate current score.

## API

```text
POST   /api/games
GET    /api/games
GET    /api/games/{game_id}
PATCH  /api/games/{game_id}
```

Scoring is not performed through normal Game PATCH.

Scoring goes through:

```text
POST /api/scoring-events
```

## Real-Time

Existing Game events:

```text
game:created
game:updated
```

M7 adds:

```text
game:score_updated
```

Example score update:

```json
{
  "game_id": "<game UUID>",
  "home_score": 2,
  "away_score": 1
}
```

## Deferred

```text
clock
timer
period / half
game-completion workflow
manual score correction
```
