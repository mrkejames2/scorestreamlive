# ScoreStreamLive M10-C Validation Fix

This package contains **validator changes only**.

Replace:

```text
scripts/validate_m10a.sh
scripts/validate_m10b.sh
scripts/validate_m10c.sh
```

No application, backend, database, migration, template, CSS, JavaScript, or
Socket.IO implementation file is changed by this package.

## Why this is necessary

M10-A and M10-B originally validated checkpoint boundaries that were correct
when those checkpoints were the latest implementation.

Later milestones intentionally add capabilities:

```text
M10-A: read-only Control Center
M10-B: live-read Socket.IO synchronization
M10-C: lifecycle mutation controls
```

A historical regression validator should verify that an earlier capability
still works. It should not require later milestones to remain within the
earlier checkpoint's scope.

## New regression philosophy

### M10-A regression

Verifies:

```text
Control Center still renders
Game state still loads from authoritative REST
teams/rosters still load
score still loads
lifecycle still loads
clock still loads
scoring history still loads
local clock rendering still exists
M9 full regression remains green
```

It no longer rejects lifecycle mutations added by M10-C.

### M10-B regression

Verifies:

```text
Socket.IO client still loads
connection UI still exists
game_id filtering still exists
reconnect still performs authoritative REST refresh
game:phase_updated still works
clock:updated still works
scoring_event:created still works
game:score_updated still works
no clock:tick listener exists
M10-A regression remains green
```

It no longer requires:

```text
page label = M10-B
Control Center = mutation-free
```

because M10-C intentionally adds lifecycle mutations.

### M10-C validation

Verifies:

```text
all four lifecycle controls
integrated M9 lifecycle transition endpoint
expected lifecycle version
expected clock version
in-flight mutation guard
409 conflict handling
no automatic retry
authoritative refresh after conflict
no scoring mutation controls
local clock rendering
no clock:tick listener
full soccer lifecycle
stale-version behavior
two-controller concurrency
M10-B regression chain
```

The `clock:tick` test checks `socket.js`, which is the actual event-consumption
module. Comments in `control.js` that mention the phrase while documenting that
it is *not* used are no longer treated as a failure.

## Install

Copy the three scripts into:

```text
scripts/
```

Then:

```bash
chmod +x scripts/validate_m10a.sh
chmod +x scripts/validate_m10b.sh
chmod +x scripts/validate_m10c.sh
```

Optional syntax check:

```bash
bash -n scripts/validate_m10a.sh
bash -n scripts/validate_m10b.sh
bash -n scripts/validate_m10c.sh
```

No Docker rebuild is required because these validators run from the host.

## Run

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m10c.sh
```

Expected validation chain:

```text
M10-C
  -> M10-B regression
      -> M10-A regression
          -> M9 full regression
```

Do not change application code to satisfy failures from the old validators.
