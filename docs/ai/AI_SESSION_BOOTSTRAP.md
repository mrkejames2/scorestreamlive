# ScoreStreamLive — New AI Session Bootstrap

Use this at the beginning of each new major-milestone AI session.

```text
You are joining an existing ScoreStreamLive project.

This is not a new application. The repository is authoritative and prior chat history is secondary context.

Before proposing implementation:

1. Read:
   - docs/ai/GOLDEN_RULE.md
   - docs/ai/AI_SESSION_BOOTSTRAP.md
   - docs/ai/DEVELOPMENT_WORKFLOW.md
   - docs/AI_HANDOFF.md
   - docs/CURRENT_MILESTONE_STATUS.md
   - docs/IMPLEMENTATION_MAP.md
   - docs/ARCHITECTURE.md
   - docs/ROADMAP.md
   - docs/MILESTONES.md
   - BACKLOG.MD
   - affected domain docs

2. Inspect the actual active branch/repository.

3. Inspect relevant Alembic migrations before changing persistence.

4. Confirm:
   - current production baseline,
   - active milestone and boundaries,
   - PostgreSQL responsibility,
   - REST responsibility,
   - Socket.IO responsibility,
   - protected architecture,
   - current validation harness,
   - likely files/domains affected.

5. Identify conflicts between documentation and repository. Repository/migrations win.

6. Do not write code until the authorized task is clear.

Rules:
- PostgreSQL is authoritative persistent state.
- REST is the persistent mutation boundary.
- Socket.IO communicates committed state.
- Preserve production-validated architecture.
- Do not expand milestone scope without approval.
- Do not implement future roadmap items early.
- Use small sub-milestones with automated validation, human acceptance, and checkpoints.
- Documentation synchronization is a required release gate.
- Deferred ideas belong in BACKLOG.MD.
```

## Current Session Boundary

```text
M0–M12 PRODUCTION COMPLETE
M13 LOCAL + HUMAN ACCEPTED
M13 PRODUCTION RELEASE PENDING
Canonical M13 harness: scripts/validate_m13h.sh

Local:      http://192.168.12.133:8000
Production: https://scorestreamlive.onrender.com
```

M13 delivered `/teams` and `/teams/{team_id}` Team/Player/Roster management around existing APIs. It did not add a Roster table, Player transfer/delete, or a new state authority.

After M13 production closure:

```text
Next roadmap milestone: M14 — Game Library / Dashboard
```

Always re-read repository state; this checkpoint is intentionally updated again if production release results change.
