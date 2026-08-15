# ScoreStreamLive — AI Handoff

## Purpose

This file is the persistent cross-session project memory for ScoreStreamLive.

AI chat history is disposable. The repository is authoritative.

## Current Production State

```text
M0–M8 COMPLETE
M8 COMPLETE — PRODUCTION VALIDATED
M9 NOT STARTED
```

## Latest Production Checkpoint

```text
Implementation commit:
ecbd6ab

Alembic:
20260814_0005

Local M8:
83 / 83 PASS

Production M8:
146 / 146 PASS

Remote M8 clock:
17 / 17 PASS

M7 production regression:
127 / 127 PASS

M6 production regression:
57 / 57 PASS

DeepSeek:
APPROVED

Render:
PASS
```

## Project

ScoreStreamLive is a real-time sports game-management and scoreboard platform.

Current development is soccer-first while preserving a generic sports engine wherever doing so does not weaken the soccer experience.

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
5. Do not redesign validated architecture without architecture approval.
6. Preserve cumulative validation harnesses.
7. Work in milestone checkpoints.
8. Repository + migrations outrank AI memory.
9. Do not introduce distributed infrastructure before a demonstrated need.

## Current Domain

```text
Game
├── Home Team
│   └── Players
├── Away Team
│   └── Players
├── home_score
├── away_score
├── ScoringEvents
└── GameClock
```

## Team / Player / Roster

Roster remains derived:

```text
Players WHERE player.team_id = team.id
```

No separate Roster table exists.

`roster:updated` is an invalidation notification containing `team_id`.

## Scoring

Game owns authoritative current score.

Scoring history is stored in `ScoringEvent`.

Successful scoring:

```text
validate
↓
ScoringEvent INSERT
+
atomic Game score increment
↓
ONE COMMIT
↓
reload
↓
scoring_event:created
↓
game:score_updated
```

## M8 GameClock

Persistent GameClock fields:

```text
id
game_id
mode
status
duration_seconds
elapsed_seconds
running_since
version
created_at
updated_at
```

Modes:

```text
count_up
count_down
```

Status:

```text
stopped
running
paused
```

One Game has at most one GameClock.

## Clock Authority

The server owns clock truth. Clients render the clock.

When not running:

```text
authoritative_elapsed = elapsed_seconds
```

When running:

```text
authoritative_elapsed =
    elapsed_seconds
    +
    floor(server_now - running_since)
```

No per-second database write exists.

No authoritative in-process timer loop exists.

No one-second Socket.IO tick exists.

## Clock REST

```text
POST  /api/games/{game_id}/clock
GET   /api/games/{game_id}/clock
PATCH /api/games/{game_id}/clock

POST /api/games/{game_id}/clock/start
POST /api/games/{game_id}/clock/pause
POST /api/games/{game_id}/clock/resume
POST /api/games/{game_id}/clock/reset
```

## Clock Concurrency

Mutations carry:

```text
expected_version
```

PostgreSQL conditional updates enforce optimistic concurrency.

Two same-version controllers cannot both commit.

Stale commands return `409`.

## Clock Socket.IO

Canonical event:

```text
clock:updated
```

Emitted after successful committed:

```text
create
configure
start
pause
resume
reset
```

Failed/stale mutations emit no clock update.

There is intentionally no:

```text
clock:tick
```

## Restart / Reconnect

Running clock truth survives:

```text
browser refresh
Socket.IO disconnect
Socket.IO reconnect
application container restart
```

because persisted anchors are authoritative.

Local final validation explicitly restarted the application while a clock was running and proved elapsed time included the restart interval.

## Soccer Added-Time Presentation

For a 45-minute count-up clock:

```text
44:59       normal
45:00–45:59 +1
46:00–46:59 +2
47:00–47:59 +3
```

Derived:

```text
floor((elapsed - duration) / 60) + 1
```

This represents elapsed added-time minute, not referee-announced stoppage time.

## Validation Assets

```text
scripts/validate_m6.sh
scripts/validate_m7.sh
scripts/validate_m8a.sh
scripts/validate_m8b.sh
scripts/validate_m8c.sh
scripts/validate_m8.sh
```

Canonical current validation entry point:

```text
scripts/validate_m8.sh
```

## Development Workflow

```text
GPT
Architecture
  ↓
Kimi / GPT Implementation Role
Implementation
  ↓
Devin
Environment / Git / Deployment
  ↓
DeepSeek
Independent Review
  ↓
GPT
Final Disposition
```

Rule:

> DeepSeek recommends. GPT decides. Implementation follows approved architecture. Deployment follows validated code.

## Milestone Gate

```text
Architecture
↓
checkpoint implementation
↓
local validation
↓
regression validation
↓
independent review
↓
GitHub
↓
Render
↓
production validation
↓
documentation synchronization
↓
next milestone
```

## Explicitly Deferred

```text
Game phases
Pregame
First Half
Halftime
Second Half
Extra Time lifecycle
production game controller
public scoreboard UI
OBS overlay
authentication
authorization
organizations
subscriptions
Redis
NATS
Kafka
microservices
```

## Next

```text
M9 — Game Lifecycle / Phases
```

M9 is not yet architected or authorized.
