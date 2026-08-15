# ScoreStreamLive — Golden Rule

## Primary Rule

> Preserve working, validated architecture. Make the smallest approved change necessary for the current milestone, prove it works, and only then continue.

## Source of Truth

```text
1. Approved architecture decision
2. Current milestone specification
3. Actual repository
4. Alembic migrations
5. docs/IMPLEMENTATION_MAP.md
6. Domain documentation
7. docs/AI_HANDOFF.md
8. Previous AI chat
```

## Technical Rules

```text
PostgreSQL = authoritative state
REST       = persistent mutation boundary
Socket.IO  = committed-state notification
```

Never emit successful state before commit.

Never invent missing repository structure.

Never rewrite working infrastructure because another design is preferred.

Never expand the milestone sideways.

## Checkpoint Rule

```text
A Persistence
 ↓ validate
B REST / Service
 ↓ validate
C Socket.IO
 ↓ validate
D Client / Docs / Regression
 ↓ validate
Independent Review
 ↓
Production
```

## Stop Conditions

Stop and report rather than guessing when:

```text
migration history differs from documentation
regression harness fails
Docker fails to start
protected infrastructure appears to require redesign
repository state cannot be inspected
requirements conflict
```

## Documentation Rule

A milestone is not fully closed until production validation and documentation synchronization are complete.
