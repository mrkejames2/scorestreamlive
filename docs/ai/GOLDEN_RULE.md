# ScoreStreamLive — Golden Rule

> Preserve working, production-validated architecture. Make only the smallest approved change required by the active milestone, prove it works, synchronize the documentation, then continue.

## Source of Truth

```text
1. Approved architecture / active milestone specification
2. Actual repository on the active branch
3. Alembic migration chain
4. IMPLEMENTATION_MAP.md + domain documentation
5. CURRENT_MILESTONE_STATUS.md
6. AI_HANDOFF.md
7. MILESTONES.md / roadmap
8. Prior AI conversation
```

## Current Checkpoint

```text
M0–M13 PRODUCTION COMPLETE

M14-0 — Validation Harness Modernization      COMPLETE
M14-A V2 — Game Library Classification        COMPLETE
M14-B V2 — Game Library Dashboard             COMPLETE
M14-C — Game Library Search & Filter          ACTIVE
M14-C IMPLEMENTATION                          NOT STARTED

Current branch:
milestone-14c-game-library-search-filter

Current pre-implementation checkpoint:
c2427d0 Complete M14-B game library dashboard
```

## Technical Rules

```text
PostgreSQL = authoritative persistent state
REST       = persistent mutation boundary
Socket.IO  = committed-state notification
```

Never emit successful state before commit.
Never invent repository state.
Never expand milestone scope without approval.
Never begin the next milestone merely because it is next.
Do not redesign validated architecture when the requirement can be satisfied by extending the existing design.

## Working Method

```text
read repository rules/state
↓
inspect implementation + migrations
↓
approve scope/boundaries
↓
small coherent change
↓
FAST domain validation
↓
FULL domain validation at acceptance
↓
human acceptance
↓
checkpoint / push
```

Use `release` scope for expensive recovery/resilience validation when appropriate.

## Validation Rule

Active M14+ validation is domain-based.

```text
scripts/validate.sh
scripts/regression/
```

Historical milestone validators remain historical acceptance evidence.

**Never rebuild a recursive milestone regression chain.**

Each active regression domain should execute once per run. Failure detail must come from logs captured during that original run rather than by recursively rerunning prior milestone validators.

`VALIDATION_MODE=local` and `VALIDATION_MODE=production` remain distinct.

## Milestone Closure Rule

```text
final FULL local validation
human acceptance
RELEASE validation when required
documentation synchronization
final branch checkpoint
merge final milestone branch → main
production deployment
production validation
delete merged milestone branches
clean main baseline
```

## Documentation Synchronization Rule

At every major milestone close, review/update as applicable:

```text
docs/AI_HANDOFF.md
docs/CURRENT_MILESTONE_STATUS.md
docs/IMPLEMENTATION_MAP.md
docs/ROADMAP.md
docs/MILESTONES.md
docs/ARCHITECTURE.md
docs/VALIDATION.md
affected domain docs
docs/DECISIONS.md
docs/DEPLOYMENT.md
docs/ai/GOLDEN_RULE.md
docs/ai/AI_SESSION_BOOTSTRAP.md
docs/ai/DEVELOPMENT_WORKFLOW.md
BACKLOG.MD
```

Documentation synchronization is part of the milestone.

## Next

M14-C is the active authorized slice, but implementation has not started.

Architect Game Library Search & Filter against the accepted M14-A/M14-B V2 layer before modifying product code.
