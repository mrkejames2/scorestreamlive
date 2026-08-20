# ScoreStreamLive AI Development System

## Purpose

The repository carries the durable development context. AI conversations are working sessions, not the source of truth.

## Required Session Reading

At the beginning of every major milestone session, read:

```text
docs/ai/GOLDEN_RULE.md
docs/ai/AI_SESSION_BOOTSTRAP.md
docs/AI_HANDOFF.md
docs/CURRENT_MILESTONE_STATUS.md
docs/IMPLEMENTATION_MAP.md
docs/ARCHITECTURE.md
docs/MILESTONES.md
BACKLOG.MD
```

Then inspect the actual active branch and relevant migrations/domain files.

## Current Checkpoint

```text
M0–M12 COMPLETE
M12 LOCAL + PRODUCTION RELEASE GATES PASS
M12 HUMAN ACCEPTANCE PASS
NEXT: M13 — Team & Roster Management UI
```

## Development Model

The workflow is role-independent and should not depend on a specific implementation or review model.

```text
Repository/rules review
↓
Architecture + explicit milestone scope
↓
Small sub-milestone implementation
↓
Automated validation + regression
↓
Human acceptance
↓
Checkpoint / push
↓
Repeat
↓
Final release gate
↓
Documentation synchronization
↓
Merge → main
↓
Production validation
```

## Core Rules

```text
PostgreSQL = authoritative persistent state
REST       = persistent mutation boundary
Socket.IO  = committed-state notification
```

Preserve validated architecture, do not invent repository state, and do not silently expand scope.

## Documentation

Documentation synchronization is required before a major milestone is considered closed. See `GOLDEN_RULE.md` for the closure checklist.
