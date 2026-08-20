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

AI chat history is useful context, but it is never more authoritative than the repository.

## Current Checkpoint

```text
M0–M12 COMPLETE
M12 LOCAL RELEASE GATE — PASS
M12 PRODUCTION RELEASE GATE — PASS
M12 HUMAN ACCEPTANCE — PASS
M13 NOT STARTED
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

Never begin the next milestone merely because it is next on the roadmap.

Do not redesign validated architecture when the requirement can be satisfied by extending the existing design.

## Working Method

Prefer one major milestone per AI session/chat.

At session start:

```text
read repository rules/state
inspect actual repository
inspect relevant migrations/domains
identify documentation drift
confirm active milestone scope
then architect/implement
```

For each sub-milestone:

```text
small approved implementation
↓
automated validation
↓
cumulative regression
↓
human acceptance
↓
checkpoint / push
```

## Validation UX Rule

Long regression runs should:

```text
show [step/total] progress
keep successful cumulative output quiet
report pass/fail totals
list failed components only
```

## Milestone Closure Rule

A major milestone is closed only after the applicable gates complete:

```text
final automated local validation
human acceptance
Git checkpoint / branch integrity
documentation synchronization
merge final milestone branch → main
production deployment
production validation
clean main baseline
```

Local-only checks (for example Docker container restart recovery) must not create false production failures. Validation modes must distinguish environment-specific checks.

## Documentation Synchronization Rule

At every major milestone close, review and update as applicable:

```text
docs/AI_HANDOFF.md
docs/CURRENT_MILESTONE_STATUS.md
docs/IMPLEMENTATION_MAP.md
docs/MILESTONES.md
docs/ARCHITECTURE.md
affected domain docs
docs/DECISIONS.md
docs/DEPLOYMENT.md
docs/ai/GOLDEN_RULE.md
BACKLOG.MD
```

Documentation synchronization is part of the milestone, not optional cleanup.
