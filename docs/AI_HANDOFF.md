# ScoreStreamLive — AI Handoff

## Purpose

This file is persistent cross-session project memory for ScoreStreamLive.

**AI chat history is disposable. The repository is authoritative.**

At the beginning of a new major-milestone session, read the repository documentation and inspect the actual repository before proposing implementation.

## Current Release

```text
M0–M12 COMPLETE
M12 LOCAL RELEASE GATE — PASS
M12 PRODUCTION RELEASE GATE — PASS
M12 HUMAN ACCEPTANCE — PASS
M13 NOT STARTED
```

Repository baseline after M12:

```text
M12 merge: fc688f7
Repository/docs cleanup: fb6cec5
Branch of record: main
```

## Environment

Local development / validation:

```text
http://192.168.12.133:8000
```

Production:

```text
https://scorestreamlive.onrender.com
```

Validation supports explicit modes:

```text
VALIDATION_MODE=local
VALIDATION_MODE=production
```

Production mode does not run Docker-only recovery checks.

## Project

ScoreStreamLive is a real-time sports game-management and broadcast-scoreboard platform.

Development is soccer-first while preserving a generic sports engine where doing so does not weaken the soccer experience.

## Core Architecture

```text
Browser / API Client
        │
   ┌────┴────┐
   │         │
 REST     Socket.IO
   │         │
   └────┬────┘
        │
     FastAPI
        │
     Services
        │
 SQLAlchemy Async
        │
   PostgreSQL
```

## Non-Negotiable Rules

1. PostgreSQL is authoritative persistent state.
2. REST is the persistent mutation boundary.
3. Socket.IO communicates committed state.
4. Successful domain events occur only after commit.
5. Preserve validated architecture unless an approved architecture change requires otherwise.
6. Preserve cumulative validation harnesses.
7. Work in milestone/sub-milestone checkpoints.
8. Repository + migrations outrank AI memory and prior conversation.
9. Do not expand active milestone scope without explicit approval.
10. Do not introduce distributed infrastructure before demonstrated need.
11. Documentation synchronization is part of milestone closure.

## Current Product Domains

```text
Game
├── Home Team
│   └── Players (derived roster)
├── Away Team
│   └── Players (derived roster)
├── Score
├── ScoringEvents
├── GameClock
└── GameLifecycle
```

Team branding is persisted and used by management, Control Center, and Broadcast Overlay surfaces.

Roster remains derived:

```text
Players WHERE player.team_id = team.id
```

No separate Roster table exists.

## Scoring

Game owns authoritative current score. Scoring history is stored in `ScoringEvent`.

Successful scoring follows:

```text
validate
↓
ScoringEvent INSERT + atomic Game score mutation
↓
ONE COMMIT
↓
reload
↓
committed-state Socket.IO notifications
```

## Clock

The server owns clock truth. Clients render from persisted state and timestamp anchors.

No per-second database write, authoritative in-process timer loop, or one-second Socket.IO tick exists.

Running clock truth survives refresh, disconnect/reconnect, and application restart.

## Lifecycle

Soccer lifecycle:

```text
pregame
↓
first_half
↓
halftime
↓
second_half
↓
full_time
```

Lifecycle meaning and GameClock time remain separate persisted domains. Integrated transitions coordinate them transactionally.

## Product Surfaces Through M12

```text
Game Management Home
Game creation/setup workflow
Inline Team selection/creation
Team branding/logos
Roster setup / Player creation
Game detail / launch hub
Control Center
Broadcast Overlay
Existing Game resume / recovery UX
```

## Validation

Canonical current release gate:

```text
scripts/validate_m12h.sh
```

Local M12-H:

```text
35 passed / 0 failed
M12-G cumulative regression: PASS
MILESTONE 12 LOCAL RELEASE GATE = PASS
```

Production M12-H:

```text
35 passed / 0 failed
M12-G cumulative: SKIPPED (local-only)
MILESTONE 12 PRODUCTION RELEASE GATE = PASS
```

Validation-script UX rules:

```text
show progress such as [1/12]
keep cumulative regression output silent unless needed
final output = passed/failed summary
list failed components only
```

## Development Workflow

One major milestone per AI chat/session is preferred.

```text
Read repository rules/state
↓
Approve milestone architecture and boundaries
↓
Create milestone sub-branch
↓
Implement smallest approved sub-milestone
↓
Automated validation + cumulative regression
↓
Human acceptance
↓
Checkpoint / push
↓
Repeat through final sub-milestone
↓
Final local + human release gate
↓
Documentation synchronization
↓
Merge final milestone branch → main
↓
Production release validation
↓
Close milestone/session
```

Deferred enhancement requests go into root `BACKLOG.MD` when the user says **Add to Backlog**. They do not automatically expand active milestone scope.

## Documentation Closure

At the end of every major milestone, review and synchronize at minimum:

```text
docs/AI_HANDOFF.md
docs/CURRENT_MILESTONE_STATUS.md
docs/IMPLEMENTATION_MAP.md
docs/MILESTONES.md
docs/ARCHITECTURE.md
affected domain docs
docs/DECISIONS.md when architecture decisions changed
docs/DEPLOYMENT.md when deployment changed
docs/ai/GOLDEN_RULE.md
BACKLOG.MD
```

## Next

```text
M13 — Team & Roster Management UI
```

M13 high-level product goal:

```text
Manage teams, players, colors, logos, and rosters through first-class UI.
```

Do not redesign the validated match engine merely to implement management UI.
