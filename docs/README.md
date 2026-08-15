# ScoreStreamLive Documentation

This directory is the project documentation source of truth.

## Current State

```text
Milestones complete: M0–M7
Current production milestone: M7
Next milestone: M8 — Game Clock / Timer Foundation
M8 status: NOT STARTED
```

Milestone 7 is production validated.

```text
Local M7 validation:      127 / 127 PASS
Production M7 validation: 127 / 127 PASS
M6 production regression:  57 / 57 PASS
Alembic head:             20260813_0004
```

## Start Here

For a human:

1. `ARCHITECTURE.md`
2. `IMPLEMENTATION_MAP.md`
3. `MILESTONES.md`
4. Domain documentation as needed

For a new AI session:

1. `AI_HANDOFF.md`
2. `IMPLEMENTATION_MAP.md`
3. `CURRENT_MILESTONE_STATUS.md`
4. current milestone specification
5. actual repository
6. `ai/GOLDEN_RULE.md`

## Files

| File | Purpose |
|---|---|
| `AI_HANDOFF.md` | Persistent cross-session project context |
| `ARCHITECTURE.md` | Architectural model and boundaries |
| `CURRENT_MILESTONE_STATUS.md` | Short live baton between AI sessions |
| `DECISIONS.md` | Architecture decision records |
| `DEPLOYMENT.md` | Local → GitHub → Render workflow |
| `GAMES.md` | Game domain |
| `IMPLEMENTATION_MAP.md` | What is actually implemented now |
| `MILESTONES.md` | Roadmap and completed milestone record |
| `MILESTONE_7.md` | Final M7 specification / completion record |
| `PLAYERS.md` | Player and roster domain |
| `SCORING.md` | M7 scoring architecture |
| `SOCKET_IO.md` | Real-time event contracts |
| `TEAMS.md` | Team domain |
| `ai/` | AI role contracts and session bootstrap |

## Documentation Rule

Documentation describes **validated implementation**, not wishes.

If repository behavior changes:

1. validate the change;
2. update the relevant domain docs;
3. update `IMPLEMENTATION_MAP.md`;
4. update `AI_HANDOFF.md`;
5. update `CURRENT_MILESTONE_STATUS.md`.

Do this before beginning the next milestone.
