# ScoreStreamLive — Game Domain

## Current State

A Game owns:

```text
identity / metadata
home_team_id
away_team_id
home_score
away_score
```

and may have:

```text
ScoringEvents
one GameClock
```

## Score

Current authoritative score remains on Game.

Scoring mutations use:

```text
POST /api/scoring-events
```

Clock mutations do not alter score.

## Clock

GameClock is a separate persistence domain keyed by unique `game_id`.

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

Clock and Game lifecycle are intentionally separate.

M8 does not add:

```text
First Half
Halftime
Second Half
Final
```

Those lifecycle concepts are deferred.
