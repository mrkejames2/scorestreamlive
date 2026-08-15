# ScoreStreamLive — AI Handoff

## Purpose

This file allows a completely new AI conversation to reconstruct ScoreStreamLive without depending on previous chat memory.

AI conversation history is disposable. The repository is persistent project memory.

## Current Production State

```text
Completed: M0–M7
Current production milestone: M7
Next planned milestone: M8
M8 status: NOT STARTED
```

Milestone 7 is fully production validated:

```text
Local M7:       127 / 127 PASS
Production M7:  127 / 127 PASS
Production M6:   57 / 57 PASS
Alembic head:   20260813_0004
DeepSeek:       APPROVED
Render:         PASS
```

## Project

ScoreStreamLive is a sports-focused real-time game-management and scoreboard platform.

Current development is soccer-first, while avoiding unnecessary design choices that would prevent later sports support.

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

### Non-negotiable rules

1. PostgreSQL is authoritative.
2. REST is the persistent mutation boundary.
3. Socket.IO communicates committed state.
4. Successful domain events occur only after database commit.
5. Do not redesign working architecture without architecture approval.
6. Do not introduce infrastructure until a milestone proves it is needed.
7. Preserve regression harnesses.
8. Work in checkpoint-sized changes.
9. Repository + migrations outrank AI memory.

## Current Domain

```text
                         GAME
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
    HOME TEAM         AWAY TEAM           SCORE
        │                 │          home_score
        ▼                 ▼          away_score
     PLAYERS           PLAYERS              │
                                              ▼
                                      SCORING EVENTS
```

## Game

Persistent Game state includes:

```text
id
name
status
scheduled_at
home_team_id
away_team_id
home_score
away_score
created_at
updated_at
```

Current score is authoritative on Game.

## Team

Teams exist independently and are referenced by Games.

## Player / Roster

Player belongs to one Team through `team_id`.

No Roster table exists.

Roster is:

```text
Players WHERE team_id = Team.id
```

Roster endpoint:

```text
GET /api/teams/{team_id}/players
```

`roster:updated` is an invalidation notification containing `team_id`; clients refetch the authoritative roster.

## Scoring

M7 introduced persistent ScoringEvents.

```text
id
game_id
team_id
player_id   nullable
event_type
created_at
```

M7 supports:

```text
event_type = goal
```

One goal adds one point.

Scoring REST:

```text
POST /api/scoring-events
GET  /api/games/{game_id}/scoring-events
```

Scoring transaction:

```text
Validate
 ↓
Create ScoringEvent
 +
Atomic PostgreSQL Game score increment
 ↓
ONE COMMIT
 ↓
Reload committed state
 ↓
scoring_event:created
 ↓
game:score_updated
```

## M7 Socket.IO

New events:

```text
scoring_event:created
game:score_updated
```

Single-request order:

```text
scoring_event:created
game:score_updated
```

Both occur after commit.

Failed scoring mutations emit neither event.

## Current Alembic Chain

Relevant latest revisions:

```text
20260813_0003 — Player / roster persistence
20260813_0004 — Game scores + ScoringEvent persistence
```

Current production schema successfully supports M7.

## Validation Assets

```text
scripts/validate_m6.sh
scripts/validate_m7a.sh
scripts/validate_m7b.sh
scripts/validate_m7c.sh
scripts/validate_m7.sh
```

`validate_m7.sh` is the final current-M7 harness.

## Development Workflow

Normal role model:

```text
GPT
Architecture
  ↓
Kimi
Implementation
  ↓
Devin
Environment / Git / Deployment
  ↓
DeepSeek
Independent Review
  ↓
GPT
Final Decision
```

During M7, GPT temporarily performed implementation work while Kimi was unavailable. This did not change the architecture governance model.

Rule:

> DeepSeek recommends. GPT decides. Implementation follows approved architecture. Devin executes environment/Git/deployment work.

## Mandatory Milestone Gate

```text
Architecture
 ↓
Checkpoint implementation
 ↓
Local validation
 ↓
Regression validation
 ↓
Independent review
 ↓
GPT disposition
 ↓
GitHub
 ↓
Render
 ↓
Production validation
 ↓
Documentation refresh
 ↓
Next milestone
```

## Source-of-Truth Hierarchy

```text
1. Approved architecture decision
2. Active milestone specification
3. Actual repository
4. Alembic migrations
5. IMPLEMENTATION_MAP.md
6. Domain documentation
7. AI_HANDOFF.md
8. Previous AI conversation
```

## Fresh AI Procedure

Before writing code:

1. read this file;
2. read `IMPLEMENTATION_MAP.md`;
3. read `CURRENT_MILESTONE_STATUS.md`;
4. read the active milestone spec;
5. inspect the repository;
6. inspect the Alembic chain;
7. describe current architecture;
8. identify expected files to change;
9. list unresolved conflicts;
10. wait for architecture approval where required.

## Explicit Deferrals

Not yet implemented:

```text
Game clock
Timer
Periods / halves
Score correction / goal undo
Production scoreboard UI
OBS overlay
Authentication
Authorization
Organizations
Seasons
Microservices
Redis
NATS
Kafka
```

## Next Milestone

```text
M8 — Game Clock / Timer Foundation
```

M8 is not architected and not authorized.

This is the intended pause point.
