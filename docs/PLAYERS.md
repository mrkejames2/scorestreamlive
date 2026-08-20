# ScoreStreamLive — Player / Roster Domain

## Status

Production domain validated; M13 Player/Roster management UI locally accepted and pending production M13 release validation.

## Player

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
    membership remains immutable through Player update

first_name
    required

last_name
    required

jersey_number
    nullable
    integer
    0–999
    duplicates allowed by the domain
```

## API

```text
POST  /api/players
GET   /api/players/{player_id}
PATCH /api/players/{player_id}
```

No Player delete endpoint exists. Player transfer remains deferred.

## Roster

Roster is derived:

```text
Players WHERE player.team_id = team.id
```

Endpoint:

```text
GET /api/teams/{team_id}/players
```

Ordering remains server/domain defined.

## M13 Management UI

Team Detail at:

```text
/teams/{team_id}
```

provides the first-class roster-management surface.

M13 capabilities include:

```text
view roster
search/sort roster in management UX
add Player
edit Player identity / jersey number
responsive/mobile roster management
```

M13 does not permit changing `team_id` through Player edit and does not add delete/transfer behavior.

## Socket.IO

```text
player:created
player:updated
roster:updated
```

Successful Player changes commit before notification. `roster:updated` tells clients to refetch authoritative roster state through REST.

## Scoring Relationship

A ScoringEvent may reference a Player. When supplied, the Player must exist and belong to the scoring Team.

## Recovery

Player and derived roster state is PostgreSQL-backed. M13-G validates that it survives local application and PostgreSQL container restarts.
