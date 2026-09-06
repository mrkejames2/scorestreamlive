# ScoreStreamLive Architecture

## Release state

```text
M0-M16  production baseline established
M17-A   Club User Administration & Lifecycle Safety             COMPLETE
M17-B   Team & Game Lifecycle Management                        COMPLETE
M17-C   Post-Game Summary & Broadcast Scene                     COMPLETE
M17-D   User Invitation & Account Activation                    COMPLETE
M17-E   Account Recovery & User Lifecycle                       COMPLETE
M17-F   Match-Day Workflow & Operator Polish                    COMPLETE
M17-G   Compact Broadcast Overlay & Brand Integration           COMPLETE
M17-H   Cohesive Product Theme & UI Consistency                 COMPLETE
M17-I   Production Supportability                               COMPLETE
M17-J   Customer Readiness & Production Release Gate            RELEASE CANDIDATE
```

## Runtime architecture

```text
Browser / API Client
        |
   +----+----+
   |         |
 REST     Socket.IO
   |         |
   +----+----+
        |
      FastAPI
        |
     Services
        |
 SQLAlchemy Async
        |
   PostgreSQL
```

## Authoritative-state contract

PostgreSQL is authoritative for persistent Game, Team, Player, score,
ScoringEvent, GameClock, GameLifecycle, Club, account, assignment, and Team
branding metadata.

REST is the durable mutation boundary.

Socket.IO is committed-state notification transport. It is not an independent
state authority.

The mutation rule remains:

```text
Validate
  -> Mutate
  -> COMMIT
  -> Reload
  -> Emit
```

GameClock remains timestamp-anchor based. There is no per-second authoritative
database write and no per-second authoritative Socket.IO tick.

## Core architectural invariants

```text
PostgreSQL = authoritative persistent state
REST       = durable mutation boundary
Socket.IO  = committed-state notification transport
Club       = tenant boundary
```

These invariants remain protected throughout M17 and the M17-J production
release gate.

## Tenant and authorization boundary

Club is the tenant boundary.

Authenticated private resources are authorized through the established
Director, Manager, and Operator role/assignment model. Direct cross-Club IDs
must not become an authorization bypass.

The public Overlay remains intentionally unauthenticated. Control and private
management APIs remain authenticated and authorized.

## Team and roster model

A Team owns persistent branding metadata such as logo URL and Team colors.
Uploaded logo bytes live outside PostgreSQL.

Roster membership remains represented by `Player.team_id`; there is no
independent Roster persistence authority.

## Match-day model

A Game composes:

```text
Game
|- Home Team
|  `- Players
|- Away Team
|  `- Players
|- Score
|- ScoringEvents
|- GameClock
`- GameLifecycle
```

Scoring history remains authoritative. A scorer-attribution correction does not
change the Game score; removal of an accidental goal changes the score exactly
once.

Lifecycle remains separate from clock time and uses committed transitions.

## Account and customer administration

M17 adds the customer-facing account lifecycle needed for Club operation:

- Director user administration
- Team and Game lifecycle management
- invitations and activation
- account recovery
- safe user lifecycle controls
- role/assignment-aware navigation and product surfaces

These capabilities do not create a second ownership or tenant model.

## Broadcast architecture

The broadcast Overlay is a public read/presentation surface backed by
authoritative Game state. Team branding and compact broadcast presentation are
presentation concerns, not new state authorities.

Control remains the authenticated operator surface.

## Production supportability

M17-I adds:

- exact deployment identity (`APP_RELEASE`)
- `X-Request-ID`
- `X-ScoreStreamLive-Release`
- structured correlation-aware logging
- logging redaction defense
- Director-only read-only support diagnostics
- PostgreSQL readiness/latency diagnostics
- incident triage documentation

`/health/live` remains dependency-free liveness.

`/health/ready` remains PostgreSQL-backed readiness.

Diagnostics do not return credentials, raw environment variables, cookies,
tokens, or cross-Club data.

## Product surfaces

Primary surfaces include:

```text
/teams
/teams/{team_id}
/games
/games/{game_id}
/games/{game_id}/setup
/control/games/{game_id}
/overlay/games/{game_id}
/api/support/diagnostics
```

## Validation architecture

`scripts/validate.sh` is the active domain-based cumulative harness.

For M17-J the expected durable domains are 35, ending with:

```text
33  Cohesive Product Theme & UI Consistency
34  Production Supportability
35  Customer Readiness & Production Release Gate
```

Historical milestone validators are acceptance records, not a recursive
execution chain.

Production release-gate checks must remain non-destructive.

## Infrastructure deliberately not present

```text
Redis
NATS
Kafka
RabbitMQ
Celery
Kubernetes
event sourcing
CQRS
distributed timer service
per-Game timer workers
```

Do not introduce these without explicit architectural approval.

## M17-J boundary

M17-J is a release/readiness milestone. It does not introduce a new product
feature, database migration, state authority, Socket.IO protocol, or deployment
topology.

M17 is not production complete until the cumulative M17-J release candidate is
merged to `main`, Render deploys it, production validation passes, and
production Human Acceptance passes.
