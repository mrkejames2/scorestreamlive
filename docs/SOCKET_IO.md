# Socket.IO Event Contract

## Transport

| Setting | Value |
|---------|-------|
| **Polling** | Enabled |
| **WebSocket** | Enabled |
| **Path** | `/socket.io/` (default) |

## Connection Lifecycle

### `connect` (built-in)
Server accepts the connection, logs it, and emits `connection:ready` to the connecting client.

### `disconnect` (built-in)
Server detects disconnect, logs it. Normal disconnects are not treated as failures.

## Events

### `connection:ready`

| Attribute | Value |
|-----------|-------|
| **Direction** | Server → Client |
| **Purpose** | Notify client that the Socket.IO connection is established |
| **Payload** | `{"socket_id": "abc123"}` |

---

### `client:ping`

| Attribute | Value |
|-----------|-------|
| **Direction** | Client → Server |
| **Purpose** | Validate bidirectional communication |
| **Payload** | `{"timestamp": "2026-08-10T18:00:00Z"}` |
| **Validation** | Payload must be a dict. `timestamp` is optional but expected. |
| **Response** | Emits `server:pong` to the sender + acknowledgement callback |

---

### `server:pong`

| Attribute | Value |
|-----------|-------|
| **Direction** | Server → Client |
| **Purpose** | Verify server-to-client communication |
| **Payload** | `{"timestamp": "...", "server_time": "..."}` |

---

### `test:broadcast`

| Attribute | Value |
|-----------|-------|
| **Direction** | Client → Server → All Clients |
| **Purpose** | Prove broadcast capability |
| **Payload** | `{"message": "Hello from Socket.IO"}` |
| **Validation** | Payload must be a dict. |
| **Broadcast scope** | All connected clients, **including** the sender. |

## Error Handling

- Invalid payload types return `{"status": "error", "reason": "invalid payload type"}` via acknowledgement.
- No stack traces, credentials, or internal details are exposed.
- Server logs contain `socket.error` events with safe metadata.

# Socket.IO Event Contract

## Overview

ScoreStreamLive uses Socket.IO for real-time bidirectional communication between browser clients and the FastAPI application. The Socket.IO server runs inside the same application container as the REST API.

## Architecture
