# ScoreStreamLive — Current Milestone Status

## Production baseline

M0 through M16 form the established production baseline on `main`.

M17 is the current cumulative customer-readiness release train.

## M17 status

```text
M17-A  Club User Administration & Lifecycle Safety             CLOSED
M17-B  Team & Game Lifecycle Management                        CLOSED
M17-C  Post-Game Summary & Broadcast Scene                     CLOSED
M17-D  User Invitation & Account Activation                    CLOSED
M17-E  Account Recovery & User Lifecycle                       CLOSED
M17-F  Match-Day Workflow & Operator Polish                    CLOSED
M17-G  Compact Broadcast Overlay & Brand Integration           CLOSED
M17-H  Cohesive Product Theme & UI Consistency                 CLOSED
M17-I  Production Supportability                               CLOSED
M17-J  Customer Readiness & Production Release Gate            RELEASE CANDIDATE
```

M17-J is the final M17 milestone.

## Accepted M17-I checkpoint

```text
Commit:            a6a766d Complete M17-I production supportability
FAST:              34 / 34 PASS
FULL:              34 / 34 PASS
Human Acceptance:  PASS
```

## M17-J release-candidate gates

Before the M17-J branch may be promoted to `main`:

```text
Local FAST                    35 / 35 PASS
Local FULL                    35 / 35 PASS
Local Human Acceptance        PASS
M17-J commit/push             COMPLETE
Working tree                  CLEAN
```

After promotion to `main` and Render deployment:

```text
Deployed release identity     VERIFIED
Production FAST               35 / 35 PASS
Production FULL               35 / 35 PASS
Production Human Acceptance   PASS
```

Until those production gates pass:

```text
M17 PRODUCTION COMPLETE = DECLARED
```

## Current product capability

The cumulative product includes:

- Club-scoped authenticated accounts and role/assignment authorization
- Director user administration and safe account lifecycle controls
- Team create/edit/branding and roster management
- Game create/manage/library/search/filter/recovery
- match-day setup and operator Control Center
- persistent authoritative GameClock and GameLifecycle
- scoring history and corrections
- compact branded public Overlay
- post-game summary and broadcast scene
- invitations, activation, and account recovery
- cohesive product theme/navigation
- production release identity, request correlation, diagnostics, and incident
  triage

## Architectural invariants

```text
PostgreSQL = authoritative persistent state
REST       = durable mutation boundary
Socket.IO  = committed-state notification transport
Club       = tenant boundary
```

The public Overlay remains unauthenticated. Control and private APIs remain
authenticated and authorized.

## Active validation model

```text
FAST     = inexpensive cumulative developer/domain feedback
FULL     = durable cumulative regression gate
RELEASE  = FULL plus explicitly registered recovery/resilience work
```

M17-J local and production promotion requires FAST and FULL. Production
validation must remain non-destructive.

## Release path

```text
M17-J local FAST/FULL/HA
  -> commit/push M17-J
  -> merge cumulative M17-J to main
  -> Render deployment
  -> verify release identity
  -> production FAST/FULL
  -> production Human Acceptance
  -> final status-record update
  -> M17 PRODUCTION COMPLETE
```

## Next milestone

Do not begin the next feature milestone until M17 production closeout is
complete.
