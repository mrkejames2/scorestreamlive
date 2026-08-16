# ScoreStreamLive — Game Lifecycle

## Milestone

```text
M9 — Game Lifecycle / Phases
```

## Current Candidate State

```text
M9-A PASS
M9-B PASS
M9-C PASS
M9-D IMPLEMENTED — LOCAL VALIDATION PENDING
```

Do not mark M9 production complete until local final validation, independent review,
Render deployment, production validation, and final documentation synchronization pass.

## Soccer Lifecycle

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

## Domain Rule

```text
GameLifecycle = meaning
GameClock     = time
```

They remain separate persisted domains.

Integrated soccer transitions coordinate them in one PostgreSQL transaction.

## Integrated Transition Contract

```json
{
  "action": "start_first_half",
  "expected_lifecycle_version": 1,
  "expected_clock_version": 1
}
```

Both versions must match.

Stale lifecycle or clock state returns `409`.

## Atomic Transition Profiles

### Start First Half

```text
phase → first_half
clock → count_up
duration → 2700
elapsed → 0
status → running
```

### End First Half

```text
phase → halftime
clock authoritative elapsed persisted
clock → paused
```

### Start Second Half

```text
phase → second_half
clock → count_up
duration → 5400
elapsed → 2700
status → running
```

The visible second half begins at `45:00`.

### End Game

```text
phase → full_time
clock authoritative elapsed persisted
clock → paused
```

## Socket.IO

M9-D events:

```text
game:phase_updated
clock:updated
```

For an integrated transition they are emitted after the shared transaction commits.

Canonical order:

```text
game:phase_updated
clock:updated
```

Both contain the same transport-only:

```text
transition_id
```

The correlation ID is not persisted.

## Failure Event Suppression

Rejected transitions emit neither M9 integrated event.

Examples:

```text
illegal transition
stale lifecycle version
stale clock version
missing clock
concurrent losing controller
```

## Recovery

Late/reconnecting clients recover with:

```text
GET lifecycle
GET clock
```

No event replay is required.

## Restart

Lifecycle and clock truth are persisted.

An active first half should remain:

```text
phase = first_half
clock = running
```

through application restart, with elapsed time including the restart interval.

## Out of Scope

```text
extra time
penalty shootout
automatic halftime
automatic full time
production Game Controller
public scoreboard
OBS overlay
authentication
multi-sport phase profiles
```
