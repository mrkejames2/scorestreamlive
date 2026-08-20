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
M0–M12 PRODUCTION COMPLETE
M13 IMPLEMENTATION COMPLETE
M13 LOCAL RELEASE GATE — PASS
M13 HUMAN ACCEPTANCE — PASS
M13 PRODUCTION RELEASE GATE — PENDING
```

Do not declare M13 fully complete before merge/deploy/production validation/branch cleanup.

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
small sub-milestone
↓
targeted automated validation
↓
silent cumulative regression
↓
human acceptance
↓
checkpoint / push
```

## Validation UX Rule

Validation should show progress, keep successful nested regression output quiet, report totals, and list failed components only.

`VALIDATION_MODE=local` and `VALIDATION_MODE=production` must remain distinct so local-only Docker/restart tests do not create false production failures.

## Milestone Closure Rule

```text
final automated local validation
human acceptance
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
affected domain docs
docs/DECISIONS.md
docs/DEPLOYMENT.md
docs/ai/GOLDEN_RULE.md
docs/ai/AI_SESSION_BOOTSTRAP.md
BACKLOG.MD
```

Documentation synchronization is part of the milestone.

## Next

After M13 production closure, the roadmap points to M14 — Game Library / Dashboard. M14 still requires a fresh repository-based startup review and explicit authorization.
