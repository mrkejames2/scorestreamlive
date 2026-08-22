# ScoreStreamLive — Milestones

## Development Model

```text
Architecture / scope
↓
small coherent sub-milestone
↓
FAST domain validation
↓
FULL domain validation at acceptance
↓
human acceptance
↓
checkpoint / push
↓
final RELEASE validation when appropriate
↓
documentation synchronization
↓
merge final milestone branch → main
↓
production deployment + validation
↓
branch cleanup / clean main
```

Historical milestone validators remain historical acceptance evidence. Active M14+ regression coverage is domain-based under `scripts/regression/` and must not recursively replay milestone history.

## Production Complete

```text
M0  — Deployment Foundation                         COMPLETE
M1  — Application Foundation                        COMPLETE
M2  — PostgreSQL Foundation                         COMPLETE
M3  — Socket.IO Foundation                          COMPLETE
M4  — Game Foundation                               COMPLETE
M5  — Team Foundation                               COMPLETE
M6  — Player / Roster Foundation                    COMPLETE
M7  — Score / ScoringEvent Foundation               COMPLETE
M8  — Game Clock / Timer Foundation                 COMPLETE
M9  — Game Lifecycle / Phases                       COMPLETE
M10 — Control Center / Match-Day Operator UX        COMPLETE
M11 — Live Scoreboard Overlay                       COMPLETE
M12 — Game Setup / Pre-Game Workflow                COMPLETE
M13 — Team & Roster Management UI                   COMPLETE
```

## M13 Historical Acceptance

Accepted sub-milestones:

```text
M13-A — Team Management Home                         PASS
M13-B — Team Create / Edit / Branding                PASS
M13-C — Team Detail & Roster View                    PASS
M13-D — Player Create / Edit                         PASS
M13-E — Roster Management UX                        PASS
M13-F — Management UX Polish / Mobile                PASS
M13-G — Recovery / Persistence / Regression          PASS
M13-H — Final Acceptance / Release Gate              PASS
```

M13 was accepted and released using the cumulative validator architecture that existed at the time. Preserve that as historical evidence; do not use it as the active M14+ regression model.

## M14 — Game Library / Dashboard

Product outcome: make persisted Games easy to discover, understand, reopen, and manage.

Current state:

```text
M14-0 — Validation Harness Modernization       COMPLETE
M14-A — Game Library Classification            COMPLETE (V2)
M14-B — Game Library Dashboard                 COMPLETE (V2)
M14-C — Game Library Search & Filter           COMPLETE
M14-D — Scalable Game Library Retrieval        COMPLETE
M14-E — Configurable Continuous Match Clock    COMPLETE
```

### M14-0

Introduced:

```text
VALIDATION_SCOPE=fast|full|release
VALIDATION_OUTPUT=summary|full
VALIDATION_FAIL_FAST=0|1
```

and a domain-based regression harness.

### M14-A V2

Introduced canonical Game Library classification:

```text
upcoming
live
completed
cancelled
```

Acceptance:

```text
FAST PASS
FULL PASS
```

### M14-B V2

Introduced grouped Game Library dashboard UX.

Acceptance:

```text
FAST PASS
FULL PASS
HUMAN ACCEPTANCE PASS
```

Checkpoint:

```text
c2427d0 Complete M14-B game library dashboard
```

### M14-C

Added Game Library Search & Filter on top of the accepted classification/dashboard architecture.

Acceptance:

```text
FAST PASS
FULL PASS
HUMAN ACCEPTANCE PASS
```

### M14-D

Added scalable retrieval behavior:

```text
bounded Game API retrieval
deterministic recency ordering
embedded Team briefs
lazy full-Team loading for Game creation
```

Acceptance:

```text
FAST PASS
FULL PASS
HUMAN ACCEPTANCE PASS
```

### M14-E

Added configurable soccer half length using the existing authoritative GameClock configuration path.

Supported presets:

```text
20 / 25 / 30 / 35 / 40 / 45 minutes
```

Continuous match-clock contract:

```text
configured half = H
first-half regulation threshold = H
second-half clock resumes at H
full-match regulation threshold = 2H
```

Control Center and Overlay freeze regulation time at the threshold while `+N` added time advances.

Acceptance:

```text
FAST PASS
FULL PASS
HUMAN ACCEPTANCE PASS
```

Checkpoint:

```text
ca64d9f Complete M14-E configurable continuous match clock
```

### M14 Release Gate

```text
FEATURE IMPLEMENTATION COMPLETE
LOCAL ACCEPTANCE COMPLETE
FINAL RELEASE SCOPE PENDING
MERGE TO MAIN PENDING
PRODUCTION VALIDATION PENDING
```

M15 must not begin until M14 is production complete.
