## Socket.IO Events

### Server → Client Events

#### `connection:ready`
Emitted when a client successfully connects.
**Payload:**
```json
{
  "status": "connected",
  "socket_id": "<socket-id>"
}
```

#### `server:pong`
Response to a `client:ping` event.
**Payload:**
```json
{
  "status": "pong",
  "timestamp": "<iso-timestamp>"
}
```

#### `test:broadcast`
Echoes a test message to all connected clients.
**Payload:**
```json
{
  "message": "<echoed-message>"
}
```

#### `game:created`
Emitted after a new Game is successfully persisted.
**Payload:** The public Game representation (includes embedded Team objects).

#### `game:updated`
Emitted after an existing Game is successfully updated.
**Payload:** The updated public Game representation.

#### `team:created`
Emitted after a new Team is successfully persisted.
**Payload:** The public Team representation.

#### `team:updated`
Emitted after an existing Team is successfully updated.
**Payload:** The updated public Team representation.

#### `player:created`
Emitted after a new Player is successfully persisted.
**Payload:** The public Player representation.

#### `player:updated`
Emitted after an existing Player is successfully updated.
**Payload:** The updated public Player representation.

#### `roster:updated` (Invalidation Notification)
**Purpose:** Notifies all connected clients that a Team's roster has changed. This is an **invalidation-only** event. Clients must retrieve the authoritative roster state via REST.

**Trigger:** Emitted after a successful `player:created` or `player:updated` event for any Player associated with the Team.

**Payload:**
```json
{
  "team_id": "<team-uuid>"
}
```

**Client Behavior:**
Upon receiving this event, clients should fetch the updated roster from:
```
GET /api/teams/{team_id}/players
```

**Rationale:**
- PostgreSQL remains the single source of truth.
- The event is small and efficient.
- Avoids sending potentially large roster payloads over Socket.IO.
- Ensures clients always have the most current data.

### Client → Server Events

#### `client:ping`
Client-initiated keepalive ping.
**Payload:**
```json
{
  "timestamp": "<iso-timestamp>"
}
```
**Server Response:** `server:pong`