# ScoreStreamLive — Golden Rule

> Preserve working, production-validated architecture. Make only the smallest approved change required by the active milestone, prove it works, then continue.

## Source of Truth

```text
1. Approved architecture
2. Active milestone specification
3. Actual repository
4. Alembic migrations
5. IMPLEMENTATION_MAP.md
6. Domain docs
7. AI_HANDOFF.md
8. Prior AI conversation
```

## Current Checkpoint

```text
M0–M8 COMPLETE
M8 PRODUCTION VALIDATED
M9 NOT STARTED
```

## Technical Rules

```text
PostgreSQL = authoritative state
REST       = persistent mutation boundary
Socket.IO  = committed-state notification
```

Never emit successful state before commit.

Never invent repository state.

Never expand milestone scope.

Never begin M9 merely because it is next on the roadmap.

## Milestone Closure Rule

A milestone is closed only after:

```text
local validation
independent review
GitHub
Render
production validation
documentation synchronization
```
