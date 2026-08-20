# ScoreStreamLive — Architecture Decisions

## Core Decisions

### PostgreSQL Is Authoritative
Persistent business state lives in PostgreSQL.

### REST Is the Persistent Mutation Boundary
Business mutations are performed through REST/service logic.

### Socket.IO Is Committed-State Notification
Successful domain events are emitted after commit.

### Roster Is Derived
No Roster table exists. Membership is `Player.team_id`.

### Game Owns Current Score
Game stores `home_score` / `away_score`.

### ScoringEvent Stores Score History
ScoringEvent insert and score increment occur in one transaction.

## Clock / Lifecycle Decisions

GameClock is a dedicated persistent domain using elapsed seconds plus UTC timestamp anchors. It supports count-up/count-down, optimistic version concurrency, and recovery without per-second database writes or authoritative per-second Socket.IO ticks.

Lifecycle remains a separate persisted domain:

```text
pregame → first_half → halftime → second_half → full_time
```

Integrated transitions coordinate lifecycle and clock transactionally.

## M13 Decisions

### Management UI Reuses Existing Domain APIs
M13 adds first-class Team/Player/Roster management surfaces without creating a parallel UI persistence layer.

### No New Roster Persistence
The management UI derives roster from `Player.team_id`; no Roster table or roster-specific persistence model was introduced.

### Player Membership Remains Immutable
M13 Player edit does not add Team transfer. Player transfer remains deferred.

### No Player Delete in M13
Player deletion is outside the approved M13 scope.

### Team Branding Remains Team State
Team colors and `logo_url` remain Team metadata. Logo image bytes remain outside PostgreSQL under the existing Team logo storage contract.

### Recovery Is Server-State Recovery
M13-G explicitly proves Team, Player, branding, and logo recovery across local application and PostgreSQL container restarts. Browser state is not authoritative.

### No New Infrastructure
M13 introduced no Redis, NATS, Kafka, RabbitMQ, Kubernetes, CQRS, event sourcing, or distributed timer infrastructure.

## Governance

Validated architecture is preserved unless an approved milestone requires change. Deferred enhancements belong in `BACKLOG.MD`.
