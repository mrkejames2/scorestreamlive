# ScoreStreamLive — New AI Session Bootstrap

Use this at the beginning of each new major-milestone AI session.

```text
You are joining an existing ScoreStreamLive project.

This is not a new application. The repository is authoritative and prior chat history is secondary context.

Before proposing implementation:

1. Read:
   - docs/ai/GOLDEN_RULE.md
   - docs/AI_HANDOFF.md
   - docs/CURRENT_MILESTONE_STATUS.md
   - docs/IMPLEMENTATION_MAP.md
   - docs/ARCHITECTURE.md
   - docs/MILESTONES.md
   - BACKLOG.MD
   - the active milestone specification when one exists
   - affected domain docs

2. Inspect the actual active branch/repository.

3. Inspect relevant Alembic migrations before changing persistence.

4. Explain/confirm:
   - current production baseline,
   - active milestone and boundaries,
   - PostgreSQL responsibility,
   - REST responsibility,
   - Socket.IO responsibility,
   - protected architecture,
   - existing validation harness,
   - likely files/domains affected.

5. Identify conflicts between documentation and repository. Repository/migrations win; repair documentation as part of the milestone.

6. Do not write code until the current authorized task is clear.

Rules:
- PostgreSQL is authoritative persistent state.
- REST is the persistent mutation boundary.
- Socket.IO communicates committed state.
- Preserve working production-validated architecture.
- Do not expand milestone scope without approval.
- Do not invent repository state.
- Do not begin future milestones early.
- Use small sub-milestones with automated validation, human acceptance, and checkpoints.
- Validation scripts show progress and summarize failures compactly.
- Documentation synchronization is a required milestone-close gate.
- Deferred ideas belong in BACKLOG.MD rather than silently expanding scope.
```

## Current Session Boundary

As of the M12 closeout:

```text
M0–M12 COMPLETE
Next: M13 — Team & Roster Management UI
Local: http://192.168.12.133:8000
Production: https://scorestreamlive.onrender.com
```

Always re-read the repository copies of these documents; do not assume this bootstrap's checkpoint remains current forever.
