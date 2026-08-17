# Milestone 10-F — Connection & Conflict UX

## Objective

Make the Control Center safe and understandable when connectivity is
interrupted or more than one controller acts on the same game.

## Reliability state machine

```text
CONNECTING
   ↓
RECOVERING
   ↓ authoritative REST refresh succeeds
LIVE

LIVE
   ↓ disconnect
OFFLINE / RECONNECTING
   ↓ transport reconnects
RECOVERING
   ↓ authoritative REST refresh succeeds
LIVE
```

Mutation controls are enabled **only** while:

```text
connectionState == live
AND socketConnected == true
AND stateAuthoritative == true
```

Transport connectivity alone is not sufficient.

## 409 conflict behavior

A stale lifecycle command:

```text
POST transition
   ↓
409
   ↓
mark browser state non-authoritative
   ↓
disable mutations
   ↓
show human-readable conflict message
   ↓
GET authoritative state
   ↓
render latest state
```

The failed command is **never automatically retried**.

## Preserved architecture

- PostgreSQL authoritative game state
- M8 anchor-based clock
- M9 atomic lifecycle/clock transitions
- M7 atomic scoring
- durable `game_elapsed_seconds`
- Socket.IO committed-state synchronization
- no per-second writes
- no browser-authoritative scores or clock

## Out of scope

- mobile layout redesign (M10-G)
- authentication / permissions
- offline mutation queue
- automatic command replay
- Redis / distributed Socket.IO
- score correction / goal undo
