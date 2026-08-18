# Milestone 12-A — Game Management Home

## Objective

Create the first normal ScoreStreamLive product entry point so a user can find an
existing Game and launch its existing Control Center or Broadcast Overlay without
knowing or copying a UUID.

## Architectural boundary

M12-A is read-only.

```text
Browser /games
   ↓
GET /api/games
   ↓
GET Teams / Lifecycle / Clock
   ↓
Render management cards
```

PostgreSQL remains authoritative.
REST remains the domain boundary.
No new Socket.IO behavior is required.
No persistence or migration changes are allowed.

## Acceptance

- `/games` returns 200 HTML.
- Existing Games render.
- Team identities resolve.
- Score renders from authoritative Game fields.
- Lifecycle state renders when present.
- Clock state renders when present.
- Missing lifecycle/clock state is tolerated.
- Control Center link targets `/control/games/{id}`.
- Overlay link targets `/overlay/games/{id}`.
- No mutation fetch exists in M12-A JS.
- M11-G regression passes.
