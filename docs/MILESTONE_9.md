# ScoreStreamLive — MILESTONE_9.md

## Milestone 9 — Game Lifecycle / Phases

**Status:** READY FOR ARCHITECTURE IMPLEMENTATION  
**Architecture Owner:** GPT  
**Workflow:** GPT → Implementation Role → Devin → DeepSeek → GPT  
**Checkpoint Model:** M9-A → M9-B → M9-C → M9-D  
**Prerequisite:** Milestones 0–8 COMPLETE and production validated  
**Starting Alembic Head:** `20260814_0005`

---

# 1. Milestone Objective

Milestone 9 introduces the authoritative **Game Lifecycle / Phase Foundation** for ScoreStreamLive.

M8 answered:

> What time is on the Game clock?

M9 answers:

> What part of the Game are we currently in?

For the first production lifecycle, ScoreStreamLive is soccer-first:

```text
PREGAME
   ↓
FIRST_HALF
   ↓
HALFTIME
   ↓
SECOND_HALF
   ↓
FULL_TIME
```

The milestone must prove that lifecycle state:

- persists in PostgreSQL;
- follows a strict legal state machine;
- is concurrency-safe;
- remains synchronized across clients;
- coordinates correctly with the existing M8 GameClock;
- preserves continuous soccer match time;
- survives reconnects and application restarts;
- preserves all M0–M8 behavior;
- remains architecturally extensible for future sports without implementing them now.

M9 is a **domain/lifecycle milestone**.

It is not the production Game Controller UI, public scoreboard UI, OBS overlay, authentication system, or multi-sport implementation.

---

# 2. Core Architectural Principle

The M9 rule is:

> **Game Lifecycle owns meaning. GameClock owns time.**

These are related but distinct domains.

Examples:

```text
phase = FIRST_HALF
clock = running
display = 37:24
```

```text
phase = HALFTIME
clock = paused
```

```text
phase = SECOND_HALF
clock = running
display = 67:11
```

Do not collapse lifecycle state into GameClock.

Do not add fields such as:

```text
first_half
second_half
halftime
period
soccer_phase
```

to the M8 `game_clocks` table.

---

# 3. Existing Architecture Must Be Preserved

M9 builds on the production-validated M8 architecture:

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

Non-negotiable rules:

1. PostgreSQL is authoritative persistent state.
2. REST is the persistent mutation boundary.
3. Socket.IO communicates committed state.
4. Successful domain events are emitted only after commit.
5. Existing M0–M8 APIs/events remain functional.
6. Existing Alembic history is never rewritten.
7. No Redis, NATS, Kafka, RabbitMQ, Kubernetes, or microservice decomposition in M9.
8. PostgreSQL remains the concurrency authority.
9. M8 GameClock architecture is preserved.
10. No per-second `clock:tick` event is introduced.

---

# 4. M9 Checkpoint Model

```text
M9-A — Lifecycle Persistence
        ↓
M9-B — Lifecycle REST + State Machine
        ↓
M9-C — Lifecycle + Clock Atomic Integration
        ↓
M9-D — Socket.IO + Validation UI + Docs + Regression
```

Each checkpoint must:

1. implement only its authorized scope;
2. include a validation harness;
3. pass locally;
4. preserve prior milestone behavior;
5. report changed files and validation results;
6. stop for GPT approval before the next checkpoint.

---

# 5. GameLifecycle Domain

M9 introduces a dedicated `GameLifecycle` domain.

Conceptually:

```text
Game
├── Teams
├── Players
├── Score
├── ScoringEvents
├── GameClock
└── GameLifecycle
```

A Game has at most one GameLifecycle.

The lifecycle represents authoritative competition phase state.

---

# 6. Persistence Model

Create a `game_lifecycles` table.

Required fields:

```text
id
game_id
phase
version
created_at
updated_at
```

Recommended constraints:

```text
id
    UUID primary key

game_id
    UUID NOT NULL
    FK → games.id
    UNIQUE

phase
    VARCHAR NOT NULL

version
    INTEGER NOT NULL
    default 1

created_at
    TIMESTAMPTZ NOT NULL

updated_at
    TIMESTAMPTZ NOT NULL
```

For the M9 soccer lifecycle, allowed persisted phases are:

```text
pregame
first_half
halftime
second_half
full_time
```

A database check constraint should enforce the allowed M9 values.

---

# 7. Why a Separate Lifecycle Table

Do not add `phase` directly to Game in M9.

A dedicated lifecycle domain provides:

- explicit concurrency/version control;
- isolation from existing Game metadata;
- a clean future boundary for sport-specific lifecycle profiles;
- easier atomic coordination with GameClock;
- minimal regression risk to the existing Game model.

The current Game remains the identity/match record.

GameLifecycle owns competition progression.

---

# 8. M9 Soccer State Machine

The only normal forward path is:

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

Allowed transition actions:

```text
start_first_half
end_first_half
start_second_half
end_game
```

Canonical transitions:

```text
pregame
  + start_first_half
  → first_half

first_half
  + end_first_half
  → halftime

halftime
  + start_second_half
  → second_half

second_half
  + end_game
  → full_time
```

All other phase/action combinations are rejected.

Examples:

```text
pregame → second_half            REJECT
first_half → full_time           REJECT
halftime → full_time             REJECT
second_half → first_half         REJECT
full_time → anything             REJECT
```

M9 does not implement backward phase correction.

A future milestone may introduce explicit administrative correction if needed.

---

# 9. Lifecycle Initialization

Required endpoint:

```text
POST /api/games/{game_id}/lifecycle
```

The lifecycle begins as:

```text
phase = pregame
version = 1
```

Conceptual response:

```json
{
  "id": "<lifecycle UUID>",
  "game_id": "<game UUID>",
  "phase": "pregame",
  "version": 1,
  "created_at": "<timestamp>",
  "updated_at": "<timestamp>"
}
```

Attempting to create a second lifecycle for the same Game returns:

```text
409 Conflict
```

Missing Game returns:

```text
404 Not Found
```

---

# 10. Lifecycle Retrieval

Required endpoint:

```text
GET /api/games/{game_id}/lifecycle
```

If lifecycle does not exist:

```text
404 Not Found
```

The response contains committed lifecycle state.

---

# 11. Lifecycle Transition Endpoint

Preferred canonical endpoint:

```text
POST /api/games/{game_id}/lifecycle/transition
```

Conceptual M9-B request:

```json
{
  "action": "start_first_half",
  "expected_version": 1
}
```

Conceptual lifecycle-only M9-B response:

```json
{
  "id": "<lifecycle UUID>",
  "game_id": "<game UUID>",
  "phase": "first_half",
  "version": 2,
  "created_at": "<timestamp>",
  "updated_at": "<timestamp>"
}
```

M9-C extends transition coordination to include the existing GameClock.

Do not create four unrelated route implementations if a single transition contract can enforce the state machine consistently.

---

# 12. Lifecycle Optimistic Concurrency

Every GameLifecycle has integer `version`.

Every successful lifecycle mutation increments it exactly once.

Transition request:

```json
{
  "action": "start_first_half",
  "expected_version": 1
}
```

The mutation succeeds only when:

```text
database lifecycle.version == expected_version
```

Otherwise:

```text
409 Conflict
```

Stale commands do not mutate lifecycle state.

---

# 13. Concurrent Lifecycle Controllers

M9-B must prove:

```text
Controller A sees lifecycle version 1
Controller B sees lifecycle version 1

A → start_first_half(version=1)
B → start_first_half(version=1)
```

Exactly one succeeds.

Expected:

```text
one 200
one 409
final phase = first_half
final lifecycle version = 2
```

The database mutation boundary must provide correctness.

Process-local locks are prohibited as the authoritative mechanism.

---

# 14. M9-B Scope Boundary

M9-B validates the lifecycle state machine independently.

M9-B must NOT alter the GameClock.

This separation is deliberate.

By the end of M9-B:

```text
Lifecycle transitions work
Clock remains unchanged
```

M9-C then proves atomic lifecycle/clock coordination.

---

# 15. Soccer Continuous Match Clock Decision

M9 locks in continuous soccer match-time presentation:

```text
FIRST HALF
0:00 → 45:00+

SECOND HALF
45:00 → 90:00+
```

The second half does NOT visually restart at `0:00`.

This supports conventional soccer match timestamps such as:

```text
Goal — 67'
```

and keeps ScoringEvent timestamps conceptually aligned with match time in future UI work.

---

# 16. First-Half Clock Profile

At the start of the first half, the M8 GameClock must represent:

```text
mode = count_up
duration_seconds = 2700
elapsed_seconds = 0
status = running
```

First-half added-time derivation remains:

```text
44:59       normal
45:00–45:59 +1
46:00–46:59 +2
47:00–47:59 +3
```

M9 must reuse the validated M8 clock arithmetic.

Do not duplicate or replace it.

---

# 17. Ending First Half

Canonical operation:

```text
first_half
+
end_first_half
```

must atomically produce:

```text
lifecycle.phase = halftime

clock.status = paused
clock.running_since = null
clock.elapsed_seconds = authoritative elapsed at transition time
```

The first-half clock may be beyond 45 minutes when stopped.

Example:

```text
phase before = first_half
clock before = 47:13 running

transition = end_first_half

phase after = halftime
clock after = 47:13 paused
```

The historical first-half overrun does not need to remain as the starting point of second-half display.

---

# 18. Starting Second Half

Canonical operation:

```text
halftime
+
start_second_half
```

must atomically produce a second-half clock anchor corresponding to:

```text
45:00
```

The target for second-half added time becomes:

```text
90:00
```

Canonical resulting clock state:

```text
mode = count_up
duration_seconds = 5400
elapsed_seconds = 2700
status = running
running_since = authoritative server time
```

This intentionally discards first-half stoppage overrun from the second-half starting display.

Example:

```text
First half ended visually at 47:13.

Second half begins visually at 45:00.
```

This matches standard soccer match-clock presentation.

---

# 19. Second-Half Added Time

With:

```text
duration_seconds = 5400
```

and continuous match elapsed time:

```text
89:59       normal
90:00–90:59 +1
91:00–91:59 +2
92:00–92:59 +3
```

The M8 generic formula continues to work:

```text
floor((elapsed - duration) / 60) + 1
```

because M9 configures the second-half target correctly.

---

# 20. Ending Game

Canonical operation:

```text
second_half
+
end_game
```

must atomically produce:

```text
lifecycle.phase = full_time
clock.status = paused
clock.running_since = null
clock.elapsed_seconds = authoritative elapsed at transition time
```

Example:

```text
phase before = second_half
clock = 93:22 running

end_game

phase = full_time
clock = 93:22 paused
```

M9 does not automatically end the Game when the clock reaches 90:00.

The operator decides when the referee has ended the match.

---

# 21. Pregame Clock Requirements

Before `start_first_half`, the GameClock must be present and compatible with soccer lifecycle integration.

Preferred M9-C requirement:

```text
GameLifecycle exists
GameClock exists
GameClock status is stopped or paused in a reset-compatible state
```

For M9, lifecycle transition code may normalize the clock to the required first-half state as part of the atomic transaction.

The operator should not need to manually synchronize lifecycle and clock state.

---

# 22. Atomic Cross-Domain Transition Rule

This is the most important M9-C requirement.

For lifecycle transitions that also modify GameClock:

```text
Lifecycle update
+
GameClock update
```

must occur in **one database transaction**.

Prohibited failure state:

```text
phase = second_half
clock = paused at 47:13
```

caused by committing lifecycle before clock mutation.

Also prohibited:

```text
phase = halftime
clock still running
```

after a successful response.

M9-C must ensure both domains commit or neither commits.

---

# 23. M8 Service Reuse / Refactor Boundary

M8 public behavior is production validated and must remain unchanged.

If atomic M9 lifecycle/clock integration requires reusable internal clock mutation helpers, the implementation may perform a **minimal internal refactor** of M8 clock service code so clock state can be changed inside an externally managed transaction.

Requirements:

- existing M8 REST behavior remains unchanged;
- existing M8 version semantics remain unchanged;
- existing M8 validation remains green;
- M8 Socket.IO semantics remain unchanged for direct clock commands;
- no duplicated clock arithmetic;
- no new public direct clock-position endpoint is exposed merely for M9.

If a larger redesign appears necessary:

> STOP and request GPT architecture review.

---

# 24. Dual-Version Concurrency Contract

By M9-C, a lifecycle transition that changes the clock must protect both authoritative domains.

Conceptual request:

```json
{
  "action": "start_second_half",
  "expected_lifecycle_version": 3,
  "expected_clock_version": 8
}
```

The transition succeeds only when both current versions match.

If lifecycle version is stale:

```text
409
```

If clock version is stale:

```text
409
```

Neither domain may be partially mutated.

---

# 25. Why Both Versions Matter

A lifecycle controller may be current on phase state but stale on clock state.

Example:

```text
Controller A:
lifecycle version = 3
clock version = 8

Controller B pauses/resets/configures the clock:
clock version becomes 9

Controller A tries start_second_half:
lifecycle expected 3
clock expected 8
```

M9-C must reject Controller A's stale command.

The lifecycle transition must not silently overwrite newer clock state.

---

# 26. M9-C Transition Semantics

Canonical soccer transition behaviors:

## start_first_half

Preconditions:

```text
phase = pregame
lifecycle version matches
clock version matches
```

Atomic result:

```text
phase = first_half
lifecycle version += 1

clock mode = count_up
clock duration = 2700
clock elapsed = 0
clock status = running
clock running_since = now
clock version += 1
```

## end_first_half

Preconditions:

```text
phase = first_half
clock status = running
both versions match
```

Atomic result:

```text
phase = halftime
lifecycle version += 1

clock elapsed = authoritative elapsed
clock status = paused
clock running_since = null
clock version += 1
```

## start_second_half

Preconditions:

```text
phase = halftime
clock not running
both versions match
```

Atomic result:

```text
phase = second_half
lifecycle version += 1

clock mode = count_up
clock duration = 5400
clock elapsed = 2700
clock status = running
clock running_since = now
clock version += 1
```

## end_game

Preconditions:

```text
phase = second_half
clock status = running
both versions match
```

Atomic result:

```text
phase = full_time
lifecycle version += 1

clock elapsed = authoritative elapsed
clock status = paused
clock running_since = null
clock version += 1
```

---

# 27. Direct Clock Commands During Active Lifecycle

M9 must explicitly define the interaction between direct M8 clock commands and lifecycle state.

M8 REST clock commands remain available.

During:

```text
first_half
second_half
```

the operator may still:

```text
pause
resume
```

the clock directly.

This supports real-world interruptions and operator correction.

However:

```text
reset
mode change
duration change
```

during an active lifecycle phase can create incompatible state.

Therefore M9-C must determine how to protect lifecycle invariants.

Preferred M9 rule:

- direct pause/resume remain allowed;
- direct reset/configuration remain allowed only if existing M8 rules permit them, but lifecycle transition commands must detect incompatible clock state and refuse to proceed rather than silently guessing.

M9 does not introduce authorization-based command restrictions.

A later Game Controller may hide unsafe controls contextually.

---

# 28. Lifecycle Does Not Auto-Advance

M9 deliberately does NOT implement:

```text
45:00 → automatically halftime
90:00 → automatically full_time
```

Soccer referees control when halves end.

Added time means regulation duration is not the phase boundary.

The operator explicitly triggers:

```text
end_first_half
end_game
```

---

# 29. No Announced Stoppage-Time Model

M9 continues the M8 distinction:

```text
elapsed added-time notation
```

is not:

```text
referee-announced stoppage time
```

M9 does not persist:

```text
announced_added_minutes
```

or similar state.

This may be a future soccer-specific feature.

---

# 30. Lifecycle Socket.IO Contract

M9-D introduces canonical lifecycle event:

```text
game:phase_updated
```

Payload conceptually:

```json
{
  "id": "<lifecycle UUID>",
  "game_id": "<game UUID>",
  "phase": "second_half",
  "version": 4,
  "created_at": "<timestamp>",
  "updated_at": "<timestamp>"
}
```

Use committed lifecycle state.

---

# 31. Clock Event During Integrated Transition

An M9-C/M9-D lifecycle transition that atomically changes GameClock must emit both committed domain snapshots:

```text
game:phase_updated
clock:updated
```

Both occur only after the shared database transaction commits.

Canonical ordering:

```text
game:phase_updated
then
clock:updated
```

This ordering must be stable and validated.

Clients must still rely on versions and authoritative state rather than assuming network delivery timing alone guarantees consistency.

---

# 32. Failed Transition Event Suppression

If any transition fails because of:

```text
illegal phase
missing lifecycle
missing clock
stale lifecycle version
stale clock version
incompatible clock status
database failure
```

then emit:

```text
no game:phase_updated
no clock:updated
```

Successful-state events must never describe a transaction that rolled back.

---

# 33. Multi-Client Synchronization

M9-D must prove at least two connected clients receive the same committed lifecycle version and phase.

For integrated transitions, both clients must receive:

```text
same game:phase_updated version
same clock:updated version
```

for the same Game.

---

# 34. Multi-Game Isolation

M9 must validate at least two Games with independent lifecycle and clock state.

Example:

```text
Game A:
phase = first_half
clock = 22:14 running

Game B:
phase = halftime
clock = 46:07 paused
```

Game A transitions must not mutate Game B.

Every lifecycle event contains `game_id`.

---

# 35. Refresh / Late Join

A client joining mid-match does not need lifecycle event replay.

Required recovery:

```text
GET lifecycle
GET clock
↓
reconstruct current Game state
↓
listen for new Socket.IO events
```

Example:

```text
phase = second_half
clock = running
authoritative elapsed = 67:31
```

The client can immediately render the match correctly.

---

# 36. Application Restart

Lifecycle state already persists directly.

GameClock restart behavior was proven in M8.

M9-D should validate a running lifecycle scenario where practical:

```text
phase = first_half
clock running
↓
restart application
↓
GET lifecycle
GET clock
↓
phase still first_half
clock still logically advancing
```

This proves that lifecycle/clock correctness does not depend on in-process phase orchestration.

---

# 37. M9 API Schemas

Conceptual schemas:

```text
GameLifecycleCreate
GameLifecycleTransition
GameLifecycleResponse
GameLifecycleTransitionResponse
```

Possible transition request fields:

M9-B:

```text
action
expected_version
```

M9-C:

```text
action
expected_lifecycle_version
expected_clock_version
```

The implementation may evolve the request schema between checkpoints before final M9 stabilization.

Final M9 API must have one canonical transition contract.

---

# 38. Transition Response

By M9-C, an integrated transition response should return enough committed state for the controller to update immediately.

Preferred conceptual response:

```json
{
  "lifecycle": {
    "game_id": "...",
    "phase": "second_half",
    "version": 4
  },
  "clock": {
    "game_id": "...",
    "status": "running",
    "mode": "count_up",
    "duration_seconds": 5400,
    "elapsed_seconds": 2700,
    "running_since": "...",
    "version": 9,
    "server_time": "..."
  }
}
```

The response represents committed state.

---

# 39. Error Contract

Expected controlled behavior:

```text
Game missing                         → 404
Lifecycle missing                    → 404
Lifecycle already exists             → 409
Clock missing for integrated action  → 409 or controlled 404
Illegal lifecycle transition         → 409
Stale lifecycle version              → 409
Stale clock version                  → 409
Incompatible clock state             → 409
Invalid action                       → 422
```

Exact response details should follow project conventions.

No internal database details should leak.

---

# 40. M9-A — Persistence Scope

M9-A implements only lifecycle persistence.

Expected:

```text
GameLifecycle ORM
Alembic migration
M9-A validation harness
```

Expected next Alembic revision:

```text
20260815_0006
```

only if repository inspection confirms `20260814_0005` is still current head.

Never overwrite existing migration history.

M9-A proves:

- table exists;
- Game FK exists;
- one lifecycle per Game;
- allowed phase constraint;
- version constraint;
- timestamp fields;
- application startup;
- M8 regression.

M9-A MUST NOT implement:

```text
lifecycle REST
lifecycle transition service
clock integration
M9 Socket.IO
production UI
```

---

# 41. M9-B — REST / Lifecycle State Machine Scope

M9-B introduces:

```text
lifecycle schemas
lifecycle service
lifecycle REST routes
state-machine validation
lifecycle optimistic concurrency
```

M9-B must prove:

```text
create → pregame
GET lifecycle
pregame → first_half
first_half → halftime
halftime → second_half
second_half → full_time
illegal transitions rejected
stale lifecycle version rejected
same-version concurrent transition has one winner
multi-Game isolation
```

M9-B must also prove:

```text
GameClock is NOT modified by lifecycle transitions yet
```

No M9 Socket.IO domain event in M9-B.

---

# 42. M9-C — Lifecycle + Clock Atomic Integration Scope

M9-C integrates the validated M9 lifecycle with the validated M8 GameClock.

This is the critical M9 checkpoint.

M9-C must prove:

```text
start_first_half:
    pregame → first_half
    clock → 0:00 running
    duration → 45:00

end_first_half:
    first_half → halftime
    clock pauses at actual elapsed time

start_second_half:
    halftime → second_half
    clock → 45:00 running
    duration target → 90:00

end_game:
    second_half → full_time
    clock pauses at actual elapsed time
```

All lifecycle+clock changes happen in one transaction.

M9-C must prove dual-version concurrency.

M9-C must keep Socket.IO lifecycle events out until M9-D unless implementation structure makes post-commit event plumbing inseparable. If so, stop for architecture review.

---

# 43. M9-D — Socket.IO / Validation UI / Docs / Regression

M9-D introduces:

```text
game:phase_updated
```

and integrated transition event validation.

M9-D also extends `/client` with technical lifecycle controls such as:

```text
Game ID
Create Lifecycle
Get Lifecycle
Current Phase
Lifecycle Version

Start First Half
End First Half
Start Second Half
End Game

Current Clock Status
Clock Version
Rendered Match Time
Lifecycle Event Log
Clock Event Log
```

This remains a technical validation client.

It is NOT the production Game Controller.

---

# 44. M9 Validation Harnesses

Create:

```text
scripts/validate_m9a.sh
scripts/validate_m9b.sh
scripts/validate_m9c.sh
scripts/validate_m9.sh
```

Final:

```text
scripts/validate_m9.sh
```

must support:

```bash
BASE_URL="http://<local>:8000" ./scripts/validate_m9.sh
```

and:

```bash
BASE_URL="https://scorestreamlive.onrender.com" ./scripts/validate_m9.sh
```

Remote validation must test remote behavior rather than incorrectly using local database state as proof of Render state.

---

# 45. Required M9-A Validation

At minimum:

```text
health/live
health/ready
info
Alembic local head
game_lifecycles table
required columns
Game FK
unique game_id
phase constraint
version default/constraint
timestamps
valid pregame persistence
invalid phase rejected
duplicate lifecycle rejected
missing Game rejected
M8 full regression
```

---

# 46. Required M9-B Validation

At minimum:

## Creation

```text
create lifecycle → 201
phase = pregame
version = 1
duplicate → 409
missing Game → 404
GET works
missing lifecycle → 404
```

## Legal State Machine

```text
pregame + start_first_half → first_half
first_half + end_first_half → halftime
halftime + start_second_half → second_half
second_half + end_game → full_time
```

## Illegal Transitions

Examples:

```text
pregame + start_second_half → reject
pregame + end_game → reject
first_half + start_first_half → reject
halftime + end_first_half → reject
full_time + any transition → reject
```

## Concurrency

```text
two same-version transitions
→ one success
→ one 409
→ one version increment
```

## Isolation

```text
Game A lifecycle mutation
does not alter
Game B lifecycle
```

## M8 Boundary

M9-B lifecycle transition must leave GameClock unchanged.

---

# 47. Required M9-C Validation

M9-C must create a real GameClock + GameLifecycle and validate the complete soccer match progression.

## Start First Half

Before:

```text
phase = pregame
clock stopped
```

After:

```text
phase = first_half
lifecycle version +1
clock count_up
clock duration = 2700
clock elapsed = 0
clock running
clock version +1
```

Wait a controlled interval and prove clock advances.

## First-Half Added Time

Where practical, set/test boundary through controlled persisted state or reusable clock helper tests:

```text
2699 → none
2700 → +1
2760 → +2
```

Do not wait 45 real minutes.

## End First Half

After:

```text
phase = halftime
clock paused
running_since null
elapsed persisted
```

## Start Second Half

After:

```text
phase = second_half
clock count_up
duration = 5400
elapsed = 2700
status = running
```

Immediate display approximately:

```text
45:00
```

## Second-Half Added Time

Validate:

```text
5399 → none
5400 → +1
5459 → +1
5460 → +2
```

## End Game

After:

```text
phase = full_time
clock paused
```

## Atomic Failure

Force at least one rejected transition and prove:

```text
lifecycle unchanged
clock unchanged
```

## Dual-Version Stale Controller

Stale lifecycle or stale clock version:

```text
409
neither domain changes
```

## Same-Version Concurrent Integrated Transition

Exactly one transaction succeeds.

Both lifecycle and clock versions increment exactly once.

---

# 48. Required M9-D Socket.IO Validation

At minimum:

```text
two Socket.IO clients connect
connection:ready regression
client:ping regression
server:pong regression
```

For each integrated lifecycle transition:

```text
game:phase_updated received
clock:updated received
both clients receive same committed versions
game:phase_updated precedes clock:updated
```

Validate:

```text
start first half
end first half
start second half
end game
```

Failed/stale transition:

```text
no game:phase_updated
no clock:updated
```

Existing events remain functional:

```text
team
game
player
roster
scoring
clock
```

No `clock:tick`.

---

# 49. Final Local M9 Validation

Final `validate_m9.sh` must prove:

```text
M9 lifecycle
M9 clock integration
M9 Socket.IO
M8 full regression
M7 regression as inherited
M6 regression as inherited
Docker startup
Alembic local head
```

It should include application restart during an active phase where practical:

```text
phase = first_half
clock running
restart app
phase still first_half
clock elapsed includes restart
```

---

# 50. Production Validation

M9 is not complete after local validation.

Required sequence:

```text
M9-D local PASS
↓
DeepSeek independent review
↓
GPT disposition
↓
Git commit / push
↓
Render deployment
↓
migration confirmation
↓
production validate_m9.sh
↓
production regression
↓
documentation synchronization
↓
M9 COMPLETE
```

---

# 51. DeepSeek Independent Review Focus

DeepSeek must specifically audit:

```text
state-machine legality
lifecycle migration
optimistic lifecycle concurrency
dual lifecycle+clock version safety
single transaction across lifecycle + clock
partial-commit risk
M8 clock regression
first-half clock semantics
second-half 45:00 start
90:00 added-time target
event suppression on failure
post-commit event ordering
restart recovery
multi-Game isolation
validation harness false-positive risk
Docker/Render compatibility
```

Findings classified:

```text
BLOCKING
REQUIRED FIX
OPTIONAL IMPROVEMENT
FUTURE MILESTONE
```

DeepSeek reviews.

GPT makes the architectural disposition.

---

# 52. Scoring Boundary

M9 does not redesign M7 scoring.

A goal can still be recorded independently of lifecycle transition endpoints.

M9 does not yet enforce:

```text
goals only allowed during first_half or second_half
```

unless explicitly added by a later product-rule milestone.

Do not silently add scoring authorization based on phase in M9.

This avoids changing a validated M7 contract without a separate requirement.

---

# 53. Game Status Boundary

Existing `Game.status` behavior must not be casually repurposed as the lifecycle state machine.

GameLifecycle is authoritative for M9 competition phase.

If existing Game status values overlap semantically, do not create automatic cross-field coupling in M9 without architecture review.

---

# 54. Clock Pause / Resume During Half

A running half may be manually paused and resumed using M8 clock endpoints.

Lifecycle phase remains:

```text
first_half
```

or:

```text
second_half
```

while the clock is paused.

This is valid.

Example:

```text
phase = first_half
clock = paused
```

means:

> the match is still in the first-half phase, but the operator has stopped the clock.

M9 lifecycle does not automatically change to another phase merely because clock status changes.

---

# 55. Halftime Clock

Canonical M9 halftime state is:

```text
phase = halftime
match clock = paused
```

M9 does not implement a separate halftime countdown clock.

A future presentation/controller milestone may add a separate interval timer if desired.

Do not overload GameClock in M9 to simultaneously represent both match clock and halftime countdown.

---

# 56. Extra Time / Overtime Boundary

M9 does NOT implement soccer extra-time periods:

```text
ET First Half
ET Halftime
ET Second Half
```

nor penalty shootout lifecycle.

Those require explicit future architecture.

The M9 lifecycle ends at:

```text
full_time
```

for the regulation two-half soccer model.

---

# 57. Future Multi-Sport Boundary

M9 should preserve the idea that lifecycle is a domain separate from GameClock.

However, M9 does NOT implement:

```text
Basketball quarters
Football quarters
Hockey periods
Futsal halves
Baseball innings
```

Do not create a universal configurable state-machine framework unless the M9 implementation genuinely requires it.

Soccer-first simplicity is preferred.

Future sports can build on or generalize the validated lifecycle boundary later.

---

# 58. Protected Architecture

Do not modify infrastructure unless required by approved implementation:

```text
Dockerfile
docker-compose.yml
entrypoint.sh
render.yaml
database initialization
Socket.IO initialization
CORS architecture
existing Alembic revisions
M7 scoring transaction
M8 GameClock public behavior
```

Any proposed modification to protected infrastructure requires architecture review.

---

# 59. Expected New Files

Subject to actual repository inspection:

```text
app/models/game_lifecycle.py
app/schemas/game_lifecycle.py
app/services/game_lifecycle_service.py
app/api/game_lifecycle.py

alembic/versions/20260815_0006_add_game_lifecycles.py

scripts/validate_m9a.sh
scripts/validate_m9b.sh
scripts/validate_m9c.sh
scripts/validate_m9.sh

docs/LIFECYCLE.md
```

Exact locations must follow repository conventions.

---

# 60. Likely Existing Files Modified

Possibly:

```text
app/main.py
app/services/game_clock_service.py
static/index.html
static/js/socket.js
docs/*
```

M9-C may require a minimal internal GameClock service refactor for shared transaction control.

Do not alter unrelated domains.

---

# 61. Observability

Lifecycle transitions should log useful fields:

```text
game_id
lifecycle_id
action
old_phase
new_phase
old_lifecycle_version
new_lifecycle_version
old_clock_version
new_clock_version
```

Do not emit continuous logs while a phase is merely active.

---

# 62. Validation Harness Evolution Rule

Historical checkpoint validators must become regression-safe as later checkpoints intentionally add functionality.

Examples:

- M9-A must not permanently assert that lifecycle REST does not exist.
- M9-B must not permanently assert that lifecycle Socket.IO does not exist.
- exact newest Alembic-head assertions belong to the active milestone final validator, while historical validators should verify their migration/schema remains present.

This prevents false regressions like those encountered and corrected during M7/M8 development.

---

# 63. AI Workflow

```text
GPT
Architecture authority
        ↓
Implementation Role
Kimi or GPT
        ↓
Devin
Environment / Git / deployment
        ↓
DeepSeek
Independent review
        ↓
GPT
Final disposition
```

Rule:

> **DeepSeek recommends. GPT decides. Implementation follows approved architecture. Deployment follows validated code.**

---

# 64. Implementation Session Startup

Before each M9 checkpoint, the implementation agent must read:

```text
docs/AI_HANDOFF.md
docs/IMPLEMENTATION_MAP.md
docs/CURRENT_MILESTONE_STATUS.md
docs/ai/GOLDEN_RULE.md
MILESTONE_9.md
```

Then inspect:

```text
actual repository
current Alembic history
M8 GameClock implementation
M8 validation harnesses
```

Do not rely on prior chat memory.

---

# 65. Checkpoint Report Format

After each checkpoint, report:

```text
Files created
Files modified
Migration state
REST behavior
Database behavior
Concurrency behavior
Socket.IO behavior
Regression results
Architecture-boundary confirmation
git status
```

Then stop for authorization.

---

# 66. M9 Acceptance Criteria

M9 is accepted only when all of the following are proven.

## Persistence

- one GameLifecycle per Game;
- lifecycle phase persists;
- allowed phase constraint enforced;
- version persists;
- Alembic chain valid.

## State Machine

- only legal soccer progression succeeds;
- illegal transitions fail;
- full_time is terminal;
- lifecycle optimistic concurrency works.

## Clock Integration

- first half starts at 0:00;
- first-half target is 45:00;
- end first half pauses current elapsed time;
- second half begins at 45:00;
- second-half target is 90:00;
- end game pauses actual final elapsed time;
- lifecycle + clock mutation is atomic.

## Concurrency

- stale lifecycle version rejected;
- stale clock version rejected;
- no partial mutation;
- same-version concurrent integrated transition has one winner.

## Real Time

- `game:phase_updated` post-commit;
- integrated transition also emits post-commit `clock:updated`;
- stable ordering;
- failed transition emits neither;
- multiple clients converge.

## Recovery

- late join retrieves lifecycle + clock;
- reconnect retrieves lifecycle + clock;
- application restart preserves active phase and running clock truth.

## Soccer

- first-half +N remains correct;
- second-half starts at 45:00;
- second-half +N begins at 90:00.

## Regression

- M8 fully passes;
- prior M7/M6 regressions remain green through cumulative harnesses;
- Docker starts cleanly;
- Render production validation passes.

## Documentation

- lifecycle docs match actual implementation;
- AI handoff is synchronized before M10 begins.

---

# 67. Explicitly Out of Scope

Do not implement in M9:

```text
production Game Controller
public scoreboard page
OBS / Streamlabs overlay
authentication
authorization
clubs / organizations
subscriptions
goal undo
score correction
referee-announced stoppage time
extra-time periods
penalty shootout lifecycle
basketball quarters
football quarters
hockey periods
baseball innings
Redis
NATS
Kafka
message brokers
microservices
Socket.IO room redesign
automatic halftime at 45:00
automatic full time at 90:00
```

---

# 68. Definition of Done

At M9 completion, ScoreStreamLive must demonstrate a complete regulation soccer match lifecycle:

```text
PREGAME
  │
  │ Start First Half
  ▼
FIRST_HALF
Clock: 0:00 → 45:00+
  │
  │ End First Half
  ▼
HALFTIME
Clock paused
  │
  │ Start Second Half
  ▼
SECOND_HALF
Clock: 45:00 → 90:00+
  │
  │ End Game
  ▼
FULL_TIME
Clock paused
```

with:

```text
PostgreSQL authority
optimistic concurrency
atomic lifecycle + clock transitions
post-commit Socket.IO
multi-client synchronization
restart recovery
multi-Game isolation
M0–M8 regression safety
```

---

# 69. Architectural Summary

```text
                         PostgreSQL
                             │
             ┌───────────────┴───────────────┐
             │                               │
      GameLifecycle                      GameClock
             │                               │
          meaning                            time
             │                               │
             └───────────────┬───────────────┘
                             │
                    M9 transition service
                             │
                  ONE atomic transaction
                             │
                           COMMIT
                             │
             ┌───────────────┴───────────────┐
             │                               │
      game:phase_updated                clock:updated
             │                               │
             └───────────────┬───────────────┘
                             │
                          CLIENTS
```

The lifecycle does not replace the clock.

The clock does not infer lifecycle.

The transition service coordinates them when soccer rules require both to change together.

---

# 70. Final Milestone Statement

Milestone 9 exists to transform ScoreStreamLive's validated Teams, Players, Scoring, and Clock foundations into an authoritative regulation soccer **Game Engine**.

At the end of M9, the backend should know:

```text
who is playing
who is on each roster
what the score is
what scoring events occurred
what time is on the match clock
what phase of the match is active
```

That is the backend foundation required before building the first real production Game Controller.

**Implementation begins with M9-A only. Each checkpoint must be validated and explicitly approved before the next begins.**
