# ScoreStreamLive — Current Milestone Status

## Production Baseline

```text
M0–M14 — PRODUCTION COMPLETE
```

M13 production merge/history remains the established production baseline on `main`.

## Active Development Milestone

```text
M14 — Game Library / Dashboard
STATUS: PRODUCTION COMPLETE
```

Accepted M14 checkpoints:

```text
M14-0 — Validation Harness Modernization       COMPLETE
M14-A V2 — Game Library Classification         COMPLETE
M14-B V2 — Game Library Dashboard              COMPLETE
M14-C — Game Library Search & Filter           COMPLETE
M14-D — Scalable Game Library Retrieval        COMPLETE
M14-E — Configurable Continuous Match Clock    COMPLETE
M14-HF1 — Match-Day Clock & Broadcast Controls COMPLETE
M14-HF2 — Scoring Corrections & Test Clock      COMPLETE
```

Current branch:

```text
milestone-14e-clock-duration-configuration
```

Current pre-M14-C implementation checkpoint:

```text
ca64d9f Complete M14-E configurable continuous match clock
```

## M14 Acceptance Evidence

M14-0:

```text
FAST     PASS
FULL     PASS
RELEASE  PASS
```

M14-A V2:

```text
FAST  PASS
FULL  PASS
```

M14-B V2:

```text
FAST              PASS
FULL              PASS
HUMAN ACCEPTANCE  PASS
```

## Current Product Capability

```text
Team Management Home
Team create/edit/branding UI
Team logo upload/replacement
Team Detail and derived roster view
Player create/edit UI
Roster search/sort/management UX
Responsive/mobile management UX

Game creation and management
Game Library canonical classification
Game Library grouped dashboard
Upcoming / Live / Completed / Cancelled classification
Scoring and scoring history
Persistent authoritative GameClock
Soccer lifecycle / phases
Integrated lifecycle + clock transitions
Socket.IO committed-state notifications
Operator Control Center
Broadcast Overlay
GUI pre-game setup workflow
Game detail / launch hub
Existing-game resume / recovery UX
```

## Active Validation Model

```text
FAST     = inexpensive developer/domain feedback
FULL     = current durable domain regression suite
RELEASE  = FULL + expensive recovery/resilience checks
```

The active harness is `scripts/validate.sh`.

Durable regression domains live in `scripts/regression/`.

Historical milestone validators remain acceptance records and must not become a recursive runtime regression chain again.

## M14 Final Release Boundary

```text
M14-A through M14-E — IMPLEMENTATION COMPLETE
LOCAL FAST/FULL/HUMAN ACCEPTANCE — PASS
LOCAL RELEASE — PASS
MERGE TO MAIN — COMPLETE
PRODUCTION FULL — PASS
PRODUCTION HUMAN ACCEPTANCE — PASS
M14 — PRODUCTION COMPLETE
```

M14 release gates are closed. M15 — Accounts & Ownership — is the next milestone.

### M14-E Continuous Soccer Clock Contract

Configured half length is `H`.

```text
First half:
  start elapsed = 0
  regulation threshold = H

Second half:
  continuous clock resumes at H
  regulation threshold = 2H
```

Added time freezes the displayed regulation clock at the threshold while `+N` advances.

```text
20:00 -> 20:00
20:01 -> 20:00 +1
21:00 -> 20:00 +2
40:00 -> 40:00
40:01 -> 40:00 +1
41:00 -> 40:00 +2
```

The lifecycle service must never restore hard-coded `2700` / `5400` transition durations.


## M14 Production Release Record

```text
Merge to main:
50aff98 Merge Milestone 14 Game Library and configurable match clock

Local RELEASE:
10 / 10 domains PASS
Recovery PASS

Production FULL:
9 / 9 domains PASS

Production Human Acceptance:
PASS
```

## Next Milestone

```text
M15 — Accounts & Ownership
STATUS: NEXT / NOT STARTED
```

## M14-HF1 / HF2 Production Closeout

Field testing after the original M14 production release produced two focused match-day reliability hotfixes.

### M14-HF1

Delivered:

```text
Pause / Resume Match Clock
Persistent Broadcast / Weather Delay Message
Continuous elapsed clock during added time
```

Production verification:

```text
FAST PASS
FULL PASS
10 / 10 domains PASS
Human production acceptance PASS
```

### M14-HF2

Delivered:

```text
Change scorer on an existing ScoringEvent
Unknown -> player
player -> different player
player -> Unknown
Remove accidental goal
Automatic team-score decrement on goal removal
Transient SCORE CORRECTION overlay banner
1 min (Test) clock preset
Active 1-minute added-time boundary regression checks
```

Production verification:

```text
FAST PASS
FULL PASS
11 / 11 domains PASS
Human verification PASS
```

Final scoring-correction invariants:

```text
Changing scorer attribution does not change the Game score.
Removing an accidental goal decrements the correct team score exactly once.
ScoringEvent history remains authoritative.
```

Final added-time validation model:

```text
1:00  regulation threshold
1:01  1:01 +1
1:59  1:59 +1
2:00  2:00 +2
```

M14-HF1 and M14-HF2 are production complete. M14 is closed.
