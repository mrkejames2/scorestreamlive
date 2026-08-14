# Game Domain

## Overview

A Game represents a sporting event and now owns the authoritative current score.

Milestone 7 adds persistent `home_score` and `away_score` fields and links Game state to durable ScoringEvent history.

## Model

| Field | Type | Required | Description |
|---|---|---:|---|
| `id` | UUID | Yes | Unique identifier, generated automatically |
| `name` | String(255) | Yes | Human-readable game name |
| `status` | String(20) | Yes | `scheduled`, `live`, `completed`, or `cancelled` |
| `scheduled_at` | DateTime(tz) | No | Optional scheduled start time |
| `home_team_id` | UUID | No | Home Team reference |
| `away_team_id` | UUID | No | Away Team reference |
| `home_score` | Integer | Yes | Authoritative home score; defaults to `0` |
| `away_score` | Integer | Yes | Authoritative away score; defaults to `0` |
| `created_at` | DateTime(tz) | Yes | Record creation timestamp |
| `updated_at` | DateTime(tz) | Yes | Last modification timestamp |

## Score Ownership

The authoritative current score is:

```text
Game.home_score
Game.away_score
```

Clients should retrieve current Game state with:

```text
GET /api/games/{game_id}
```

Clients do not calculate the current score by replaying scoring history.

## Scoring Events

Milestone 7 introduces durable `ScoringEvent` records with:

- `id`
- `game_id`
- `team_id`
- `player_id` — nullable
- `event_type`
- `created_at`

The supported M7 event type is:

```text
goal
```

One accepted goal adds one point to the scoring Team.

## Scoring REST API

Create a scoring event:

```text
POST /api/scoring-events
```

Retrieve Game scoring history:

```text
GET /api/games/{game_id}/scoring-events
```

Scoring history is ordered by:

```text
created_at ASC
id ASC
```

## Scoring Validation

The service validates that:

- the Game exists;
- the Team belongs to the Game;
- a supplied Player exists;
- a supplied Player belongs to the scoring Team;
- `event_type` is `goal`.

`player_id = null` is valid.

## Atomic Score Mutation

ScoringEvent creation and Game score increment occur in one transaction.

The Game score is incremented with a concurrency-safe atomic PostgreSQL `UPDATE`, preventing lost increments from simultaneous accepted goals.

## Direct Score Mutation

Milestone 7 does not expose manual score override through the normal Game update endpoint.

Score correction, undo, decrement, and scoring-event deletion are deferred.

## Status Lifecycle

Existing Game status behavior remains unchanged by Milestone 7.
