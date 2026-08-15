# ScoreStreamLive — Game Domain

## Status

Production validated through Milestone 8.

## Game

Current Game state includes:

```text
identity / metadata
home_team_id
away_team_id
home_score
away_score
```

A Game may also have:

```text
ScoringEvents
one GameClock
```

## Score

Authoritative current score remains on Game.

Scoring mutations use:

```text
POST /api/scoring-events
```

Clock mutations do not alter score.

## GameClock

A Game has at most one GameClock.

Clock operations:

```text
POST  /api/games/{game_id}/clock
GET   /api/games/{game_id}/clock
PATCH /api/games/{game_id}/clock

POST /api/games/{game_id}/clock/start
POST /api/games/{game_id}/clock/pause
POST /api/games/{game_id}/clock/resume
POST /api/games/{game_id}/clock/reset
```

Clock and Game lifecycle remain separate concepts.

## Deferred

```text
Pregame
First Half
Halftime
Second Half
Extra Time
Final
```

These are expected to be addressed in a later lifecycle milestone.
