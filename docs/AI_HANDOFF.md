# ScoreStreamLive — AI Handoff

## Current Status

```text
M0–M7 COMPLETE / PRODUCTION VALIDATED

M8-A Clock Persistence            PASS
M8-B REST / Clock Engine          PASS
M8-C Real-Time Synchronization    PASS
M8-D Finalization                 IN PROGRESS
```

M8 is not production-complete yet.

Pending:

```text
M8-D final local validation
DeepSeek independent review
GPT disposition
GitHub push
Render deployment
production M8 validation
final documentation status flip
```

## Core Architecture

```text
PostgreSQL = authoritative persistent state
REST       = persistent mutation boundary
Socket.IO  = post-commit committed-state notification
```

## Current Domain

```text
Game
├── Teams
│   └── Players / derived Rosters
├── Score
├── ScoringEvents
└── GameClock
```

## M8 GameClock

Persistent:

```text
id
game_id UNIQUE
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

States:

```text
stopped
running
paused
```

Clock truth is reconstructed from persisted elapsed state and UTC timestamp anchor.

No one-second Socket.IO tick exists.

No background per-Game timer is authoritative.

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

Mutations require `expected_version`.

Same-version concurrent controllers result in one winner and stale conflicts.

## Clock Socket.IO

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

Failed/stale commands emit no clock update.

## Soccer Added-Time Presentation

For a 45-minute count-up target:

```text
45:00–45:59 → +1
46:00–46:59 → +2
47:00–47:59 → +3
```

This is derived presentation state, not announced referee stoppage time.

## Current Migration Head

```text
20260814_0005
```

## Validation State

```text
M8-A: 44/44 PASS
M8-B: 79/79 PASS
M8-C: 75/75 PASS
M7:   127/127 PASS through regression chain
M6:    57/57 PASS through regression chain
```

M8-D introduces the canonical final `scripts/validate_m8.sh` and restart validation.

## Next Milestone

Directional only:

```text
M9 — Game Lifecycle / Phases
```

Do not implement M9 until M8 is independently reviewed, deployed, production validated, and documentation is finalized.
