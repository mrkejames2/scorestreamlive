# ScoreStreamLive — Team Domain

## Status

Production domain validated; M13 management UI locally accepted and pending production M13 release validation.

## Purpose

Team represents a sports team referenced by Games and Players.

## Persistent Fields

```text
id
name
short_name
logo_url
primary_color
secondary_color
created_at
updated_at
```

`logo_url` is persistent metadata. Logo image bytes are deliberately not stored in PostgreSQL.

## API

```text
POST   /api/teams
GET    /api/teams
GET    /api/teams/{team_id}
PATCH  /api/teams/{team_id}
POST   /api/teams/{team_id}/logo
GET    /api/teams/{team_id}/players
```

## M13 Web UI

```text
/teams
/teams/{team_id}
```

`/teams` is the Team Management Home and supports Team discovery, creation, editing, and branding.

`/teams/{team_id}` is Team Detail and provides Team identity/branding plus derived roster management.

M13 management surfaces use the existing REST APIs for persistent mutations. Browser state is not authoritative.

## Branding

Team supports:

```text
short name
primary color
secondary color
logo
```

Logo upload/replacement is handled through the Team logo endpoint and storage service. Local Docker uses a persistent Team-logo volume so uploaded logos survive application/container recovery.

## Player Relationship / Roster

Players belong to Team through:

```text
Player.team_id
```

Roster remains derived:

```text
Players WHERE player.team_id = team.id
```

No separate Roster table exists.

## Game Relationship

Games reference Teams through `home_team_id` and `away_team_id`.

## Socket.IO

```text
team:created
team:updated
roster:updated
```

Successful notifications represent committed state.

## M13 Boundaries

M13 did not introduce Team deletion, a Roster table, or a new persistence model.

## Validation

M13-G proves Team identity/branding/logo persistence across local app and PostgreSQL restart recovery. M13-H is the canonical final M13 release gate.
