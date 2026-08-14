## Socket.IO Events

Socket.IO is a notification layer for committed application state. PostgreSQL remains authoritative.

### Server → Client Events

#### `connection:ready`

Emitted when a client successfully connects.

```json
{
  "status": "connected",
  "socket_id": "<socket-id>"
}
```

#### `server:pong`

Response to a `client:ping` event.

```json
{
  "status": "pong",
  "timestamp": "<iso-timestamp>"
}
```

#### `test:broadcast`

Echoes a test message to all connected clients.

```json
{
  "message": "<echoed-message>"
}
```

#### `game:created`

Emitted after a new Game is successfully persisted.

Payload: the public Game representation, including current `home_score` and `away_score`.

#### `game:updated`

Emitted after an existing Game is successfully updated.

Payload: the updated public Game representation.

#### `team:created`

Emitted after a new Team is successfully persisted.

Payload: the public Team representation.

#### `team:updated`

Emitted after an existing Team is successfully updated.

Payload: the updated public Team representation.

#### `player:created`

Emitted after a new Player is successfully persisted.

Payload: the public Player representation.

#### `player:updated`

Emitted after an existing Player is successfully updated.

Payload: the updated public Player representation.

#### `roster:updated` — invalidation notification

Notifies clients that a Team roster changed.

```json
{
  "team_id": "<team-uuid>"
}
```

The full roster is intentionally not included. Clients retrieve authoritative roster state from:

```text
GET /api/teams/{team_id}/players
```

#### `scoring_event:created`

Emitted after a scoring transaction successfully commits.

```json
{
  "id": "<event UUID>",
  "game_id": "<game UUID>",
  "team_id": "<team UUID>",
  "player_id": "<player UUID or null>",
  "event_type": "goal",
  "created_at": "<ISO timestamp>"
}
```

The event represents durable ScoringEvent history.

#### `game:score_updated`

Emitted after the same successful scoring transaction commits and after `scoring_event:created`.

```json
{
  "game_id": "<game UUID>",
  "home_score": 1,
  "away_score": 0
}
```

This is the authoritative committed score snapshot for the notification. Clients can retrieve current Game state through REST.

### Milestone 7 Scoring Event Order

For one successful scoring mutation:

```text
COMMIT
  ↓
reload committed state
  ↓
scoring_event:created
  ↓
game:score_updated
```

Failed scoring requests emit neither M7 successful-state event.

Concurrent scoring requests are not required to produce globally monotonic intermediate Socket.IO score payloads. The guarantees are durable accepted events, no lost score increments, one M7 event pair per accepted mutation, and correct final authoritative Game state.

### Client → Server Events

#### `client:ping`

Client-initiated keepalive ping.

```json
{
  "timestamp": "<iso-timestamp>"
}
```

Server response: `server:pong`.

### Validation Client

The `/client` page is a technical diagnostic client. It displays connection lifecycle, Team/Game/Player/Roster events, `scoring_event:created`, and `game:score_updated`.

It is not the production scoreboard UI.
