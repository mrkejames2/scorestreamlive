# M16-B — Socket.IO Reliability & Isolation

## Objective

Make Socket.IO delivery game-scoped, reconnect-safe, and tenant-aware without changing the authoritative-state model established by M16-A.

## Authority invariant

PostgreSQL and server-side REST state remain authoritative. Socket.IO only announces committed state changes. Reconnect does not replay a historical event stream; clients re-fetch authoritative state.

## Room contract

Each Game has two audience-specific transport rooms:

- `game:<game_id>:public` — logged-out public Overlay clients.
- `game:<game_id>:control` — authenticated and authorized Control Center clients.

The Game ID is the match-day isolation boundary. The public/control suffix preserves the existing M15 public/private boundary and prevents future privileged socket events from being accidentally exposed to logged-out Overlay clients.

Known match-day events that previously used global `sio.emit(...)` are intercepted by `GameScopedAsyncServer` and delivered only to the matching Game's public and control rooms. If a known match-day event has no Game identity, it is blocked rather than broadcast globally. The legacy `test:broadcast` diagnostic remains global because it is not match-day domain traffic.

## Subscription rules

The Overlay supplies `{game_id, audience: "overlay"}` in the Socket.IO handshake. The server verifies the Game exists and joins the public room before the browser's `connect` callback runs.

The Control Center explicitly sends `game:subscribe` with `{game_id, audience: "control"}`. The server resolves the existing M15 session cookie and requires `can_operate_game(...)` before entering the control room. Repeated subscriptions are idempotent. If the same socket changes Game/audience, its previous Game room is left first.

## Reconnect contract

Room membership is re-established for each new Socket.IO connection. The Control Center still gates mutation readiness on its authoritative HTTP refresh. The Overlay still reloads `/api/public/games/<game_id>/overlay-state`. Existing client-side Game ID filters remain as defense-in-depth.

## Non-goals

No Redis, NATS, Kafka, event replay, distributed socket manager, horizontal scaling, Socket.IO microservice, WebSocket replacement, offline-first behavior, or general M16-C security hardening is introduced here.

## Human acceptance

Use two Games and, where available, two Clubs. Keep a public Overlay and authenticated Control Center open for Game A, and another Overlay/Control Center for Game B. Verify Game A score/clock/phase/correction events update only Game A clients; Game B events update only Game B clients. Refresh/reconnect each surface and confirm it converges from authoritative state. Verify a logged-out Overlay still works. Verify an unauthorized Control Center socket cannot subscribe to a Game outside its permitted Club/resource scope. Finally repeat the M16-A refresh/restart/correction recovery flow to confirm no regression.
