# ScoreStreamLive Validation Architecture

## Purpose

The active regression system is domain-based and executes each active check once.

Historical milestone validators remain acceptance records; the active orchestrator does not recursively replay them.

## Controls

```text
VALIDATION_MODE=local|production
VALIDATION_SCOPE=fast|full|release
VALIDATION_OUTPUT=summary|full
VALIDATION_FAIL_FAST=0|1
```

## Scopes

### fast

Cheap developer feedback.

Rules:

- no application-container restart;
- no PostgreSQL-container restart;
- run current inexpensive domain checks once;
- intended for frequent development use.

### full

Current durable domain regression suite.

Rules:

- run each registered domain once;
- continue through failures by default so one run produces the complete failure inventory;
- do not replay historical milestone validators.

### release

Release/resilience confidence.

Includes the current domain suite plus expensive recovery checks such as application and PostgreSQL restart validation where appropriate.

## Output

Every run captures logs under:

```text
.validation/runs/<timestamp>/
```

and updates:

```text
.validation/latest
```

`VALIDATION_OUTPUT=summary` prints concise status while retaining detailed logs.

`VALIDATION_OUTPUT=full` prints detailed failures from the same captured run.

**Diagnostic output must not rerun the regression suite merely to expose why it failed.**

## Active Orchestrator

```text
scripts/validate.sh
```

Current durable domains:

```text
scripts/regression/health.sh
scripts/regression/surfaces.sh
scripts/regression/api_reads.sh
scripts/regression/architecture.sh
scripts/regression/game_library.sh
scripts/regression/game_dashboard.sh
scripts/regression/game_search_filter.sh
scripts/regression/game_retrieval.sh
scripts/regression/game_clock_configuration.sh
scripts/regression/recovery.sh
```

Recovery is registered only in `release` scope.

## Milestone Validators

M14+ milestone validators are thin wrappers around the active harness.

Examples:

```text
scripts/validate_m14_0.sh
scripts/validate_m14a.sh
scripts/validate_m14b.sh
scripts/validate_m14c.sh
scripts/validate_m14d.sh
scripts/validate_m14e.sh
```

A new milestone may add or strengthen durable domain coverage, but must not create another recursive chain of historical milestone validators.

## Historical Validation

Historical validators such as the M13 release chain remain valid evidence for how those milestones were accepted.

They are not the active runtime regression engine for M14+ development.

## Failure Workflow

```text
run FAST or FULL
↓
domain fails
↓
read captured domain log
↓
fix the actual failure
↓
rerun only the appropriate scope
```

Avoid manually drilling through milestone history to discover the first real failure.

## Standard Commands

FAST:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
VALIDATION_MODE=local \
VALIDATION_SCOPE=fast \
VALIDATION_OUTPUT=full \
./scripts/validate_mXX.sh
```

FULL:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
VALIDATION_MODE=local \
VALIDATION_SCOPE=full \
VALIDATION_OUTPUT=full \
./scripts/validate_mXX.sh
```

RELEASE:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
VALIDATION_MODE=local \
VALIDATION_SCOPE=release \
VALIDATION_OUTPUT=full \
./scripts/validate_mXX.sh
```

## M14-E Game Clock Configuration Contract

The durable `Game Clock Configuration` domain protects:

```text
supported 20/25/30/35/40/45 minute presets
authoritative GameClock PATCH path
running-clock configuration guard
no hard-coded 45/90 lifecycle overwrite
first-half threshold H
second-half start H
full-match threshold 2H
Control Center regulation freeze + added time
Overlay regulation freeze + added time
```

Boundary examples:

```text
20:00 -> no +1
20:01 -> +1
20:59 -> +1
21:00 -> +2

40:00 -> no +1
40:01 -> +1
40:59 -> +1
41:00 -> +2
```
