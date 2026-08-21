# ScoreStreamLive — Development Workflow

## Goal

Keep development fast without sacrificing architectural control or repeatability.

The workflow is intentionally independent of any specific AI model or coding assistant.

## Major-Milestone Session Model

Prefer one AI conversation/session per major milestone.

At the beginning of the session:

1. Read the required repository documents listed in `AI_SESSION_BOOTSTRAP.md`.
2. Inspect the active repository branch and relevant migrations/domain code.
3. Confirm the current production baseline.
4. Confirm the active milestone's goal, boundaries, and acceptance criteria.
5. Identify documentation/repository conflicts before implementation.

## Sub-Milestone Cycle

```text
approved scope
↓
create/continue milestone branch
↓
implement smallest coherent change
↓
run targeted automated validation
↓
run cumulative regression silently
↓
human acceptance
↓
checkpoint commit + push
↓
next sub-milestone
```

Do not advance after a failed gate unless the failure is understood and explicitly dispositioned.

## Validation Standards

Active validation uses the domain-based harness documented in `docs/VALIDATION.md`.

Controls: `VALIDATION_MODE=local|production`, `VALIDATION_SCOPE=fast|full|release`, `VALIDATION_OUTPUT=summary|full`, and `VALIDATION_FAIL_FAST=0|1`.

The active regression suite executes each domain once, captures detailed logs during the original run, and never recursively replays historical milestone validators. Expensive application/PostgreSQL restart testing belongs to release scope. Historical milestone validators remain acceptance records; durable current regression coverage belongs under `scripts/regression/`.

Current production endpoint:

```text
https://scorestreamlive.onrender.com
```

## Human Acceptance

Automated validation proves contracts and regressions. Human acceptance proves the workflow actually looks and behaves correctly to an operator/viewer.

Record explicit acceptance before checkpointing UI/product sub-milestones.

## Branching

For a major milestone such as M13:

```text
main
 └─ milestone/m13-a-...
      └─ milestone/m13-b-...
           └─ ...
                └─ milestone/m13-h-final-acceptance
```

Each new sub-milestone branch starts from the accepted previous sub-milestone. After final acceptance, merge only the final branch into `main`; its history contains the complete chain.

Keep old milestone branches until the final merge and production verification succeed, then delete merged local/remote branches.

## Backlog Rule

When the user says **Add to Backlog**, record the enhancement in root `BACKLOG.MD` and continue the approved milestone unless the user explicitly changes scope.

## Major-Milestone Closure

```text
final automated local gate
↓
human acceptance
↓
documentation synchronization
↓
checkpoint final milestone branch
↓
merge final branch → main
↓
push main
↓
production validation
↓
branch cleanup
↓
clean main baseline
↓
close AI session
```

## Documentation Gate

Before closure, synchronize current state, implementation map, roadmap, architecture, affected domains, decisions/deployment when applicable, AI handoff/rules, and backlog.

The next milestone begins from repository documentation, not from assumptions carried over from the previous conversation.
