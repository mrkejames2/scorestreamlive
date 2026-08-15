# ScoreStreamLive Documentation

This directory is the project documentation source of truth.

## Current State

```text
M0–M8 COMPLETE
M8 COMPLETE — PRODUCTION VALIDATED
M9 NOT STARTED
```

## Latest Production Checkpoint

```text
Implementation commit: ecbd6ab
Alembic head:          20260814_0005

Local M8 validation:      83 / 83 PASS
Production M8 validation: 146 / 146 PASS
Remote M8 clock tests:     17 / 17 PASS
M7 production regression: 127 / 127 PASS
M6 production regression:  57 / 57 PASS

DeepSeek: APPROVED
Render:   PASS
```

## Start Here

For a human:

1. `ARCHITECTURE.md`
2. `IMPLEMENTATION_MAP.md`
3. `CURRENT_MILESTONE_STATUS.md`
4. `CLOCK.md`
5. domain documentation as needed

For a new AI session:

1. `AI_HANDOFF.md`
2. `IMPLEMENTATION_MAP.md`
3. `CURRENT_MILESTONE_STATUS.md`
4. `ai/GOLDEN_RULE.md`
5. the next approved milestone specification
6. the actual repository
7. Alembic migration history

## Documentation Rule

Documentation describes validated implementation, not desired future behavior.

Before the next milestone begins:

```text
production validation
↓
documentation synchronization
↓
clean Git checkpoint
↓
next architecture
```
