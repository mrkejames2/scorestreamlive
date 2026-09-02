# M16-B HF1 — Control Socket Subscription Repair

## Trigger

M16-B automated FAST and FULL validation passed, but Human Acceptance exposed a real-time regression: goals persisted correctly and the public Overlay updated immediately, while open Control Center windows did not update until manual refresh.

Application logs showed successful `audience=overlay` subscriptions but no corresponding `audience=control` room subscription for the affected Control Center sockets.

## Root cause

The server correctly stopped globally broadcasting match-day events in M16-B. A browser that still had the pre-M16-B Control socket module cached could connect using the old behavior: it performed authoritative HTTP recovery but never sent the new `game:subscribe` command. That left the Control socket connected but outside `game:<id>:control`, so scoped scoring events reached the Overlay but not the Control Center.

## Repair

HF1 keeps game-room isolation intact and does not restore global broadcasts.

1. Current Control clients now include `{game_id, audience: "control"}` in the Socket.IO handshake. The existing explicit `game:subscribe` remains as an idempotent confirmation before authoritative recovery.
2. The server adds a narrow compatibility path for already-cached pre-M16-B Control clients. When no handshake subscription is supplied, it may infer a game only from the `/control/games/<uuid>` Referer.
3. The inferred game never grants access. It is passed through the same `_subscribe_game()` path, which resolves the authenticated session and applies `can_operate_game()` before entering the control room.
4. If an initial Control subscription is denied, the socket connection is rejected rather than remaining connected but unscoped.
5. Existing public Overlay behavior, authoritative HTTP recovery, client-side game-id filtering, and server-side room isolation remain unchanged.

## Human acceptance focus

- Open two Control Centers for the same game and one Overlay.
- Record a goal from either Control Center.
- Both Control Centers and the Overlay must update without refresh.
- Open a second game simultaneously and confirm no cross-game updates.
- Refresh/reconnect and confirm each client reconstructs authoritative state.
- Confirm logs contain `socket.subscription.active` with `audience=control` for Control Center sockets.

No migration is required. Alembic head remains `20260902_0013`.
