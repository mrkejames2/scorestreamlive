# M16-A — Match-Day State & Recovery Hardening

## Objective

Make active-match state safe across browser refresh, temporary network loss,
device sleep/wake, Socket.IO reconnect, stale operator windows, duplicate
scoring-command replay, and application restart.

## Authority

PostgreSQL/server state is authoritative.

Socket.IO transports notifications and committed snapshots. It is not the
authoritative store. A client that connects or reconnects must reconcile with
server state before privileged match-day mutations are considered safe.

## Existing recovery behavior preserved

The persisted GameClock already stores status, duration, accumulated elapsed
seconds, `running_since`, and an optimistic version. Current elapsed time is
derived on the server from that durable anchor.

The Control Center already marks state non-authoritative during disconnect and
performs an authoritative refresh before re-enabling match-day controls.

The public Overlay already reloads the unauthenticated overlay-state snapshot
on initial load, reconnect, relevant live updates, and visibility return.

M16-A deliberately preserves these behaviors rather than introducing a new
clock engine, Redis, event sourcing, offline-first storage, or distributed
locking.

## New M16-A behavior

Scoring commands may carry a caller-generated `request_id`.

When the same request is replayed:

- the server returns the already-committed scoring event;
- the team score is not incremented again;
- duplicate Socket.IO scoring notifications are not emitted.

The request identity is persisted in `scoring_events` and protected by a
unique database index, closing concurrent replay races while keeping all score
changes and scoring-event creation in the existing single transaction.

Historical scoring rows remain valid because `request_id` is nullable.

## Validation

M16-A adds the cumulative `Match-Day Recovery` regression domain and the
`validate_m16a.sh` milestone entrypoint.

Production validation is read-only/non-destructive. It verifies recovery
architecture and liveness but never creates a synthetic production goal.

Human acceptance must include:

1. Start a controlled local match and run the clock.
2. Record a goal, refresh Control Center, and verify score/history/clock.
3. Refresh the logged-out Overlay and verify the same state.
4. Interrupt/reconnect the client and verify controls stay paused until
   authoritative recovery completes.
5. Sleep/wake or background/foreground the display and verify recovery.
6. Open a second Control Center and verify stale clock transitions are rejected
   and refreshed.
7. Replay one scoring POST with the identical `request_id`; verify only one
   scoring event and one score increment exist.
8. Restart the local application/container while the clock is running and
   verify the recovered clock continues from the persisted anchor.
9. Perform a scorer correction and verify both Control Center and Overlay.
10. Run cumulative FAST, then FULL validation.

## Explicit non-goals

M16-A does not add Redis, NATS, a message broker, distributed locking,
event sourcing, service workers, offline-first support, a Socket.IO room
redesign, multi-region failover, new match-day features, or new sports.
