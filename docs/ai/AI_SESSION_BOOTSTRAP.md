# ScoreStreamLive — New AI Session Bootstrap

Copy this into a fresh implementation/review session after attaching or providing repository access.

```text
You are joining an existing ScoreStreamLive project.

This is not a new application.

Before proposing code:

1. Read:
   - docs/AI_HANDOFF.md
   - docs/IMPLEMENTATION_MAP.md
   - docs/CURRENT_MILESTONE_STATUS.md
   - docs/ai/GOLDEN_RULE.md
   - the active MILESTONE_X.md if one exists.

2. Inspect the actual repository.

3. Inspect the Alembic migration chain.

4. Explain:
   - current production domain,
   - current milestone state,
   - PostgreSQL responsibility,
   - REST responsibility,
   - Socket.IO responsibility,
   - protected architecture,
   - existing validation harness,
   - expected files to change.

5. Identify any conflict between documentation and repository.

6. Do not write code until the current authorized task is clear.

Rules:
- PostgreSQL is authoritative.
- REST is the persistent mutation boundary.
- Socket.IO communicates committed state.
- Preserve working architecture.
- Do not expand milestone scope.
- Do not invent repository state.
- Do not begin future milestones early.
```
