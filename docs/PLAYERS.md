# ScoreStreamLive — Player / Roster Domain

## Status

Production validated through Milestone 7.

## Player

Conceptual fields:

```text
id
team_id
first_name
last_name
jersey_number
created_at
updated_at
```

## Rules

```text
team_id
    required
    FK → Team
    current architecture treats membership as immutable

first_name
    required

last_name
    required

jersey_number
    nullable
    integer
    0–999
    duplicates allowed
```

## API

```text
POST  /api/players
GET   /api/players/{player_id}
PATCH /api/players/{player_id}
```

No Player delete endpoint exists.

Player transfer is deferred.

## Roster

Roster is derived:

```text
Players WHERE player.team_id = team.id
```

Endpoint:

```text
GET /api/teams/{team_id}/players
```

Ordering:

```text
jersey_number ASC NULLS LAST
last_name ASC
first_name ASC
id ASC
```

## Socket.IO

```text
player:created
player:updated
roster:updated
```

Event order on successful create/update:

```text
COMMIT
 ↓
player event
 ↓
roster:updated
```

`roster:updated` payload:

```json
{
  "team_id": "<team UUID>"
}
```

The client refetches the roster through REST.

## M7 Scoring Relationship

A ScoringEvent may contain a Player ID.

If supplied:

```text
Player must exist
Player must belong to scoring Team
```

`player_id` may be null for an unknown/unavailable scorer.
