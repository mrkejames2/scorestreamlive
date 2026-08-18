# ScoreStreamLive — AI HANDOFF

**Project:** ScoreStreamLive  
**Purpose:** Persistent project context for AI-assisted development  
**Current Local Baseline:** Milestones 0–11 implemented and locally accepted  
**Current Milestone State:** Milestone 11 COMPLETE — automated and human acceptance PASS  
**Deployment State:** M11 Git commit/push and Render production validation are the next operational steps  
**Next Planned Milestone:** Milestone 12 — not yet architected or authorized  

---

# 1. Purpose

AI chat history is not the project's source of truth.

At the start of a fresh AI development session provide:

```text
AI_HANDOFF.md
IMPLEMENTATION_MAP.md
Current MILESTONE_X.md
Current repository
```

The current repository, committed migrations, approved architecture decisions, validation harnesses, and current project documentation are authoritative.

---

# 2. Project Overview

ScoreStreamLive is a sports-focused real-time game management, match-control, scoreboard, and broadcast-overlay platform.

Current evolution:

```text
Game Management
      ↓
Teams
      ↓
Players / Rosters
      ↓
Game Score / Scoring Events
      ↓
Persistent Game Clock
      ↓
Game Lifecycle / Halves
      ↓
Mobile Control Center
      ↓
Read-Only Broadcast Overlay
      ↓
Live Goal + Match-State Presentation
```

The project is intentionally developed in small validated milestones.

---

# 3. Development Philosophy

> Build the smallest reliable architectural layer required for the next capability, validate it, document the resulting implementation, and only then move forward.

Every milestone should preserve:

```text
Architecture
Implementation
Local Validation
Regression Validation
Human Acceptance where applicable
Independent Review / Production Validation when required
Documentation Refresh
```

Do not expand sideways into unrelated platform features before the current product path is stable.

---

# 4. AI Workflow

Normal workflow:

```text
GPT
Solution Architect / Final Architecture Decision
   ↓
Kimi K2
Primary Implementation Engineer
   ↓
Devin
Environment / Git / Deployment / Validation
   ↓
DeepSeek
Independent Reviewer / Second Opinion
   ↓
GPT
Final Disposition
```

Rule:

> DeepSeek recommends. GPT decides. Implementation follows approved architecture. Devin validates and deploys.

---

# 5. Infrastructure

Local:

```text
Ubuntu VM
Docker
Docker Compose
```

Application:

```text
Python
FastAPI
SQLAlchemy async
asyncpg
PostgreSQL
Alembic
Pydantic
python-socketio
Uvicorn
HTML / CSS / JavaScript browser clients
```

Source control:

```text
GitHub
```

Production:

```text
Render
```

Deployment path:

```text
Local VM → GitHub → Render → Production Validation
```

---

# 6. Core Architecture Rules

1. **PostgreSQL is authoritative for persistent domain state.**
2. **REST is the persistent mutation boundary.**
3. **Socket.IO communicates committed state changes.**
4. **Never emit successful domain state before commit.**
5. **Clients re-read authoritative REST state after reconnect/recovery where required.**
6. **The broadcast overlay is read-only.**
7. **No `clock:tick` per-second server broadcast architecture.**
8. **Do not redesign working architecture without architecture approval.**
9. **Avoid premature Redis, Kafka, NATS, Kubernetes, CQRS, event sourcing, or microservices.**
10. **The repository is project memory; AI conversation memory is not.**

Canonical persistent mutation pattern:

```text
REST
 ↓
Validation
 ↓
Service
 ↓
PostgreSQL
 ↓
COMMIT
 ↓
Reload committed state
 ↓
Socket.IO
 ↓
Connected Clients
```

---

# 7. Completed Milestones

```text
M0  Deployment Foundation                 COMPLETE
M1  Application Foundation                COMPLETE
M2  PostgreSQL Foundation                 COMPLETE
M3  Socket.IO Foundation                  COMPLETE
M4  Game / Match Foundation               COMPLETE
M5  Team Foundation                       COMPLETE
M6  Player / Roster Foundation            COMPLETE
M7  Game Score / Scoring Events           COMPLETE
M8  Persistent Game Clock                 COMPLETE
M9  Game Lifecycle / Atomic Integration   COMPLETE
M10 Mobile Match Control Center           COMPLETE
M11 Broadcast Overlay                     COMPLETE
```

M11 local completion was explicitly accepted by the human operator after automated release-gate validation and GUI testing.

---

# 8. Current Domain

```text
                              GAME
                               │
         ┌─────────────────────┼─────────────────────┐
         ▼                     ▼                     ▼
     HOME TEAM             AWAY TEAM             SCORE
         │                     │             home_score
         ▼                     ▼             away_score
      PLAYERS               PLAYERS                 │
                                                   ▼
                                            SCORING EVENTS
                               │
                               ├──────── GAME CLOCK
                               │
                               └──────── GAME LIFECYCLE
```

There is no separate Roster table; Player carries `team_id`.

---

# 9. Score / Scoring Architecture

Authoritative current score:

```text
Game.home_score
Game.away_score
```

Scoring mutations create a durable `ScoringEvent` and atomically update the Game score in one transaction.

Current scoring event fields include:

```text
id
game_id
team_id
player_id                 nullable
event_type
game_elapsed_seconds      durable match-time snapshot
created_at
```

Current supported scoring event:

```text
event_type = goal
```

`player_id` may be null, representing Team Goal / Unknown Scorer.

After a successful Control Center goal submission, the scorer selector resets to Team Goal / Unknown Scorer to avoid accidental scorer carryover.

Important events:

```text
scoring_event:created
game:score_updated
```

Failed scoring mutations do not alter score and do not emit successful scoring events.

---

# 10. Game Clock Architecture

The Game Clock is persistent server-authoritative state.

Key state includes:

```text
mode
status
duration_seconds
elapsed_seconds
running_since
version
server_time
authoritative_elapsed_seconds
display_seconds
```

The server does **not** emit a per-second `clock:tick`.

Committed clock/lifecycle changes use Socket.IO invalidation/state-change events, while browser displays interpolate locally.

Final cross-display timing model established during M11-F:

```text
Authoritative clock snapshot
        ↓
monotonic performance.now() anchor
        ↓
local 250ms visual rendering
        ↓
5-second clock-only authoritative re-anchor
```

Both Control Center and Broadcast Overlay use this model.

Human acceptance requirement established in M11-F:

```text
Control Center vs Overlay difference <= 1 second
```

A five-minute side-by-side human test passed, remaining within one second and usually nearly exact.

The local Ubuntu VM clock must remain NTP-synchronized. A prior VM time-sync problem caused misleading clock behavior during M11-C troubleshooting; Chrony synchronization was corrected before final acceptance.

---

# 11. Game Lifecycle Architecture

Lifecycle phases:

```text
pregame
first_half
halftime
second_half
full_time
```

Lifecycle and clock transitions are integrated atomically and guarded by optimistic versions.

The Control Center sends expected lifecycle and clock versions.

Stale or competing mutations return `409` and are not automatically retried.

Two controllers using the same stale version produce one committed action and one conflict while authoritative state remains consistent.

Relevant real-time events include committed phase/clock updates used as invalidation/state-change notifications.

---

# 12. Milestone 10 — Control Center

M10 delivered the phone-first match operator surface.

Key capabilities:

```text
mobile / tablet responsive layout
persistent live connection status
authoritative REST bootstrap
Socket.IO live synchronization
lifecycle controls
clock display
home / away goal controls
scorer selectors
scoring summary
rosters
optimistic conflict protection
reconnect / recovery state
large touch targets
```

Phone is the primary UX benchmark; tablet support is secondary but validated.

The Control Center must not perform client-side score arithmetic.

Mutation controls remain paused unless live connection and authoritative state are confirmed.

M10-H final automated acceptance passed and human acceptance completed.

---

# 13. Milestone 11 — Broadcast Overlay

**Status: COMPLETE.**

M11 sub-milestones:

```text
M11-A  Read-only overlay foundation                 PASS
M11-B  Live Socket.IO synchronization               PASS
M11-C  Clock precision                              PASS
M11-D  Broadcast visual presentation                PASS + HUMAN PASS
M11-E  Goal presentation                            PASS + HUMAN PASS
M11-F  Match-state presentation / clock sync        PASS + HUMAN PASS
M11-G  Final release / certification gate           PASS + HUMAN PASS
```

Final M11-G automated result:

```text
scripts/validate_m11g.sh
67 passed
0 failed
```

The final release gate also confirmed the M11-F clock-sync architecture and cumulative regression chain.

M11-G GUI / human demo passed.

---

# 14. Broadcast Overlay Architecture

Route pattern:

```text
/overlay/games/{game_id}
```

Overlay responsibilities:

```text
GET authoritative Game state
GET Team state
GET lifecycle state
GET clock state
GET rosters
render scoreboard
interpolate clock locally
listen for committed Socket.IO events
recover authoritative state after reconnect
remain read-only
```

Overlay guardrails:

```text
No POST mutations
No client-side score authority
No clock:tick consumer
Transparent browser-source canvas
Preserve last-known-good display during temporary recovery failures
```

M11-D added broadcast-quality visual presentation for 1280x720 and 1920x1080 use.

M11-E added automatic GOAL presentation:

```text
GOAL
scoring team
scorer name when available
match minute from game_elapsed_seconds
~5 second automatic dismissal
```

Null scorer displays a Team Goal fallback.

M11-F added automatic lifecycle presentation:

```text
FIRST HALF
HALFTIME + score
SECOND HALF
FULL TIME + score
```

Lifecycle presentation auto-clears and contains replay protection so bootstrap/reconnect does not replay stale banners.

---

# 15. Real-Time / Recovery Rules

Socket.IO is used for committed-state notification, not as the persistent source of truth.

On reconnect:

```text
connection restored
      ↓
client enters recovering state
      ↓
REST authoritative refresh
      ↓
state marked authoritative
      ↓
controls re-enabled / overlay resumes live state
```

Control Center mutation readiness requires:

```text
socket connected
AND
state authoritative
AND
no relevant command already in flight
```

Overlay recovery preserves last-known-good broadcast state where possible.

---

# 16. Validation Assets

Important cumulative harnesses include:

```text
scripts/validate_m6.sh
scripts/validate_m7.sh
scripts/validate_m8.sh
scripts/validate_m9.sh
scripts/validate_m10h.sh
scripts/validate_m11a.sh
scripts/validate_m11b.sh
scripts/validate_m11c.sh
scripts/validate_m11d.sh
scripts/validate_m11e.sh
scripts/validate_m11f.sh
scripts/validate_m11f_clock_sync.sh
scripts/validate_m11g.sh
```

Final M11-G automated release gate:

```text
M11-G FINAL ACCEPTANCE PASSED
Passed: 67
Failed: 0
```

The M11-G validator was subsequently cleaned up so the `clock:tick` static check pipes Control Center and Overlay source through stdin instead of accidentally passing JavaScript contents to `grep` as a filename.

---

# 17. Alembic State

Known milestone revisions include:

```text
M6 Player revision              20260813_0003
M7 scoring revision             20260813_0004
M8/M9 clock/lifecycle lineage   through 20260815_0006
M10-E scoring elapsed snapshot  20260817_0007
```

Current known local head from M10-E/M11 work:

```text
20260817_0007 (head)
```

M10 and M11 UI/broadcast work introduced no new database migration after that head.

Do not rewrite existing migrations casually.

---

# 18. Current Deployment Gate

Milestone 11 is locally complete and human accepted.

Next operational steps:

```text
Fix/commit final M11-G validator cleanup
      ↓
Commit refreshed AI_HANDOFF.md
      ↓
Review git diff/status
      ↓
Git commit
      ↓
Git push
      ↓
Render deployment
      ↓
Production health / smoke validation
      ↓
Production M11 validation as appropriate
      ↓
Confirm deployed baseline before M12 implementation
```

Do not describe the new M11 build as Render-production-validated until that deployment/validation occurs.

---

# 19. Next Planned Milestone

```text
M12 — NOT YET ARCHITECTED OR AUTHORIZED
```

Do not infer M12 scope from old directional roadmaps.

Before M12 coding begins:

1. Confirm Git/Render baseline is clean.
2. Read this handoff and `IMPLEMENTATION_MAP.md`.
3. Inspect actual repository state.
4. Review remaining product roadmap and choose the smallest next product capability.
5. Create/approve the M12 specification before implementation.

---

# 20. Fresh AI Session Procedure

At the beginning of a new AI conversation:

1. Read `AI_HANDOFF.md`.
2. Read `IMPLEMENTATION_MAP.md`.
3. Read the active milestone specification.
4. Inspect the actual repository.
5. Inspect Alembic history.
6. Reconstruct current architecture before changing code.
7. Surface conflicts or unresolved architecture questions.
8. Do not redesign established behavior based on preference.
9. Work in approved checkpoints.
10. Run cumulative regression after each checkpoint.

---

# 21. Source-of-Truth Hierarchy

When information conflicts:

```text
1. Approved architecture decisions
2. Current milestone specification
3. Actual repository
4. Database migrations
5. IMPLEMENTATION_MAP.md
6. Current docs/
7. AI_HANDOFF.md
8. Prior AI chat history
```

---

# 22. Current Handoff Summary

```text
PROJECT
ScoreStreamLive

LOCAL COMPLETE
M0–M11

M11 FINAL STATE
M11-A PASS
M11-B PASS
M11-C PASS
M11-D PASS + HUMAN PASS
M11-E PASS + HUMAN PASS
M11-F PASS + HUMAN PASS
M11-G 67/67 PASS + HUMAN PASS
M11 COMPLETE

CURRENT DOMAIN
Game
 ├── Home Team → Players
 ├── Away Team → Players
 ├── home_score / away_score
 ├── ScoringEvents + game_elapsed_seconds
 ├── GameClock
 └── GameLifecycle

MATCH OPERATOR
Phone-first Control Center

BROADCAST
Read-only transparent overlay
Live score / phase / clock
Goal banners
Lifecycle banners
No refresh required during normal operation

CLOCK MODEL
Server authoritative snapshot
+ performance.now() interpolation
+ 5-second authoritative re-anchor
Control Center / Overlay <= 1 second human acceptance

SOURCE OF TRUTH
PostgreSQL

MUTATION BOUNDARY
REST

REAL-TIME DELIVERY
Socket.IO after commit
No clock:tick

ALEMBIC HEAD
20260817_0007

FINAL M11 HARNESS
scripts/validate_m11g.sh
67 / 67 PASS

PENDING OPERATIONAL STEP
Git commit / push → Render deployment / validation

NEXT
M12 — not yet architected or authorized
```
