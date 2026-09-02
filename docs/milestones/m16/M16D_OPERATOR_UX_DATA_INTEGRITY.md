# M16-D — Operator UX & Data Integrity Hardening

M16-D hardens match-day operation against accidental destructive commands,
stale-controller actions, and unnecessary scoring corrections while preserving
the authoritative-state, Socket.IO isolation, and tenant-security boundaries
established by M16-A through M16-C.

## Scope

- Require confirmation before End First Half and End Game.
- Keep match-day mutations disabled while state is not authoritative/live.
- Keep scoring correction controls disabled during recovery/reconnect.
- Treat selecting the already-current scorer as a no-op in both the browser
  and scoring service.
- Reconcile authoritative state after scorer correction and goal removal.
- Improve operator feedback for goal creation, scorer correction, goal
  deletion, and controller conflicts.
- Preserve request-ID scoring idempotency, Team/Game validation, Player/Team
  validation, non-negative score protection, lifecycle optimistic concurrency,
  and clock optimistic concurrency.
- Add the `Operator UX/Data Integrity` validation domain.

## Database

No Alembic migration. Expected head remains `20260902_0013`.

## Public boundary

The logged-out Overlay and deliberate public overlay snapshot are unchanged.
M16-D does not alter Socket.IO room architecture or M16-C tenant authorization.

## Non-goals

No Control Center redesign, event sourcing, undo subsystem, audit-log platform,
offline mode, Redis/queues, authentication redesign, new sports, new production
infrastructure, or broad database integrity rewrite.
