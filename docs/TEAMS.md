# ScoreStreamLive — Team Domain

## Status

Production validated.

## Purpose

Team represents a sports team referenced by Games and Players.

Conceptual fields:

```text
id
name
short_name
created_at
updated_at
```

## API

```text
POST   /api/teams
GET    /api/teams
GET    /api/teams/{team_id}
PATCH  /api/teams/{team_id}
GET    /api/teams/{team_id}/players
```

## Game Relationship

Games reference Teams as:

```text
home_team_id
away_team_id
```

## Player Relationship

Players belong to a Team through:

```text
Player.team_id
```

## Roster

No separate roster table exists.

The Team roster is derived by querying Players.

## Scoring Validation

In M7, a Team can score only when it participates in the target Game as Home or Away Team.

## Socket.IO

```text
team:created
team:updated
```

Roster changes are represented separately with:

```text
roster:updated
```
