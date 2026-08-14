# ScoreStreamLive Architecture

## Domain Model — Milestone 7 (Score / Scoring Events)

Milestone 7 extends the production-validated Game → Team → Player model with persistent score state and durable scoring history.

```text
                         GAME
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
    HOME TEAM         AWAY TEAM           SCORE
        │                 │          home_score
        ▼                 ▼          away_score
     PLAYERS           PLAYERS              │
                                              ▼
                                      SCORING EVENTS
```

## Source of Truth

- **PostgreSQL** is the authoritative source for Game score and ScoringEvent history.
- **REST** is the mutation boundary.
- **Socket.IO** notifies connected clients about committed state.
- Clients must not treat Socket.IO or browser memory as authoritative state.

## Game Score

The `games` table stores:

- `home_score` — integer, required, default `0`
- `away_score` — integer, required, default `0`

The current displayed score is read from the Game record. Clients do not calculate the current score by replaying ScoringEvents.

## ScoringEvent Entity

A ScoringEvent records an accepted scoring mutation.

Fields:

- `id`
- `game_id`
- `team_id`
- `player_id` — nullable
- `event_type`
- `created_at`

Milestone 7 supports only:

```text
event_type = goal
```

One accepted goal increments the scoring Team by exactly one.

## Validation Rules

A scoring request is valid only when:

1. The Game exists.
2. The scoring Team is the Game's home or away Team.
3. If `player_id` is supplied, the Player exists.
4. If `player_id` is supplied, the Player belongs to the scoring Team.
5. `event_type` is `goal`.

A null `player_id` is valid.

## Transaction Boundary

ScoringEvent creation and score increment are one logical database transaction.

```text
POST /api/scoring-events
        ↓
Validation
        ↓
Create ScoringEvent
        ↓
Atomic PostgreSQL score UPDATE
        ↓
ONE COMMIT
        ↓
Reload committed state
        ↓
Socket.IO notifications
```

The score increment uses an atomic PostgreSQL update rather than an ORM read/increment/write cycle. This prevents lost increments when valid scoring requests arrive concurrently.

## REST API Boundaries

### Scoring

```text
POST /api/scoring-events
GET  /api/games/{game_id}/scoring-events
```

### Existing Game State

```text
GET /api/games/{game_id}
```

returns authoritative `home_score` and `away_score`.

Direct score mutation through the normal Game PATCH endpoint is not part of Milestone 7.

## Socket.IO Event Flow

After a successful scoring transaction commits:

```text
scoring_event:created
        ↓
game:score_updated
```

### `scoring_event:created`

Contains the committed ScoringEvent representation.

### `game:score_updated`

Contains:

```json
{
  "game_id": "<game UUID>",
  "home_score": 1,
  "away_score": 0
}
```

No successful-state M7 events are emitted for failed scoring requests.

## Existing Player / Roster Architecture

Players still belong to Teams through `Player.team_id`.

A Team roster is still derived by querying Players for that Team. No separate Roster table exists.

`roster:updated` remains invalidation-only; clients refetch the authoritative roster through REST.

## Out of Scope for Milestone 7

Milestone 7 does not implement:

- score correction or goal undo
- scoring-event deletion or editing
- game clock
- periods / halves
- assists
- cards
- substitutions
- statistics
- authentication / authorization
- production scoreboard UI
- OBS overlay
- Redis, NATS, Kafka, or microservice decomposition
