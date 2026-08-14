# ScoreStreamLive --- MILESTONE 7

## Game Score + Scoring Event Foundation

**Milestone:** 7\
**Status:** IMPLEMENTATION + LOCAL VALIDATION COMPLETE --- AWAITING
INDEPENDENT REVIEW / PRODUCTION VALIDATION\
**Prerequisite:** Milestones 0--6 complete and production validated\
**Workflow:** GPT → Implementation Engineer → Devin → DeepSeek → GPT\
**Implementation model:** M7-A → M7-B → M7-C → M7-D\
**Next expected milestone:** M8 --- Game Clock / Timer Foundation\
**Do not begin M8 until M7 production validation and handoff refresh are
complete.**

------------------------------------------------------------------------

# 1. Milestone Purpose

Milestone 7 introduces the first persistent live game-state mutation in
ScoreStreamLive:

``` text
Game
 ↓
Score
 ↓
Scoring Events
```

M7 allows ScoreStreamLive to:

-   maintain authoritative home and away scores for a Game;
-   record which Team scored and, optionally, which Player scored;
-   validate that scoring data belongs to the Game;
-   persist score and scoring history in PostgreSQL;
-   notify connected clients only after successful commit;
-   preserve all M0--M6 behavior.

M7 does **not** implement the game clock, scoreboard presentation, OBS
overlay, score correction, substitutions, cards, statistics,
authentication, or a generalized multi-sport scoring engine.

------------------------------------------------------------------------

# 2. Governing Architecture

The established rules remain authoritative:

1.  **PostgreSQL is the source of truth.**
2.  **REST is the mutation boundary.**
3.  **Socket.IO communicates committed state; it is not storage.**
4.  **Successful-state Socket.IO events occur only after database
    commit.**
5.  **M7 extends M0--M6 rather than redesigning them.**
6.  **No premature Redis, NATS, Kafka, RabbitMQ, CQRS, event sourcing,
    Kubernetes, distributed Socket.IO, or microservice decomposition.**

Canonical mutation flow:

``` text
REST Request
    ↓
Validation
    ↓
Scoring Service
    ↓
PostgreSQL transaction
    ├── create ScoringEvent
    └── atomically increment Game score
    ↓
COMMIT
    ↓
Reload committed state
    ↓
scoring_event:created
    ↓
game:score_updated
    ↓
REST Response / Connected Clients
```

------------------------------------------------------------------------

# 3. Final M7 Domain Model

``` text
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

M7 intentionally does **not** introduce a separate `game_state` table.

Current score:

``` text
games.home_score
games.away_score
```

Scoring history:

``` text
scoring_events
```

Clients retrieve authoritative current score from the Game. They do not
reconstruct current score by replaying ScoringEvents.

------------------------------------------------------------------------

# 4. Game Score Contract

Game contains:

``` text
home_score
    INTEGER
    NOT NULL
    default 0

away_score
    INTEGER
    NOT NULL
    default 0
```

New Games begin `0–0`.

A valid M7 scoring action increments exactly one side by exactly one.

Direct score correction, decrement, undo, and manual score override are
not part of M7.

------------------------------------------------------------------------

# 5. ScoringEvent Contract

Persistent fields:

``` text
id
    UUID
    primary key

game_id
    UUID
    NOT NULL
    FK → games.id
    ON DELETE RESTRICT

team_id
    UUID
    NOT NULL
    FK → teams.id
    ON DELETE RESTRICT

player_id
    UUID
    NULLABLE
    FK → players.id
    ON DELETE RESTRICT

event_type
    VARCHAR(50)
    NOT NULL

created_at
    timezone-aware timestamp
    NOT NULL
```

Index:

``` text
ix_scoring_events_game_id
```

M7 supports only:

``` text
event_type = "goal"
```

`player_id` is nullable so an accepted goal can be recorded when the
scorer is unknown or unavailable in the roster.

------------------------------------------------------------------------

# 6. Validation Rules

A scoring request is accepted only when:

1.  Game exists.
2.  Team belongs to the Game as home or away Team.
3.  If `player_id` is supplied, Player exists.
4.  If `player_id` is supplied, Player belongs to the scoring Team.
5.  `event_type` is `goal`.

Expected controlled failures:

``` text
Unrelated Team       → 422
Missing Player       → 422
Wrong-Team Player    → 422
Invalid event_type   → 422
Missing Game history → 404
```

Failed scoring requests must:

``` text
NOT increment score
NOT create ScoringEvent
NOT emit scoring_event:created
NOT emit game:score_updated
```

------------------------------------------------------------------------

# 7. REST API Contract

M7 adds:

``` text
POST /api/scoring-events
GET  /api/games/{game_id}/scoring-events
```

Existing:

``` text
GET /api/games/{game_id}
```

returns authoritative:

``` text
home_score
away_score
```

Scoring history ordering:

``` text
created_at ASC
id ASC
```

------------------------------------------------------------------------

# 8. Transaction and Concurrency Contract

ScoringEvent creation and Game score increment are one logical
transaction using the same SQLAlchemy session.

The score increment uses an atomic PostgreSQL update conceptually
equivalent to:

``` sql
UPDATE games
SET home_score = home_score + 1
```

or the away-score equivalent.

The implementation must not use a naïve concurrent read-modify-write
pattern that can lose accepted goals.

No Redis or distributed lock is required.

------------------------------------------------------------------------

# 9. Socket.IO Contract

M7 adds exactly:

``` text
scoring_event:created
game:score_updated
```

## scoring_event:created

``` json
{
  "id": "<event UUID>",
  "game_id": "<game UUID>",
  "team_id": "<team UUID>",
  "player_id": "<player UUID or null>",
  "event_type": "goal",
  "created_at": "<ISO timestamp>"
}
```

## game:score_updated

``` json
{
  "game_id": "<game UUID>",
  "home_score": 1,
  "away_score": 0
}
```

Canonical single-request ordering:

``` text
COMMIT
 ↓
reload committed state
 ↓
scoring_event:created
 ↓
game:score_updated
```

Concurrent requests are not required to deliver globally monotonic
intermediate Socket.IO score snapshots. Required guarantees are no lost
accepted score increments, durable events, one event pair per accepted
mutation, and correct final authoritative Game state.

Existing M3--M6 Socket.IO contracts remain intact.

------------------------------------------------------------------------

# 10. Database Migration

M7 migration:

``` text
20260813_0004
```

Previous revision:

``` text
20260813_0003
```

M7 migration:

-   adds `home_score` to `games`;
-   adds `away_score` to `games`;
-   initializes existing Games safely to zero;
-   creates `scoring_events`;
-   creates foreign keys;
-   creates `ix_scoring_events_game_id`.

Current local Alembic result:

``` text
20260813_0004 (head)
```

Existing M0--M6 migrations must not be rewritten.

------------------------------------------------------------------------

# 11. Checkpoint Record

## M7-A --- Persistence --- PASS

Implemented:

-   Game score persistence;
-   ScoringEvent ORM model;
-   migration `20260813_0004`;
-   persistence validation.

No REST scoring or M7 Socket.IO behavior was introduced during the A
checkpoint.

## M7-B --- REST / Service --- PASS

Implemented:

-   ScoringEvent schemas;
-   scoring service;
-   scoring REST endpoints;
-   Game/Team/Player validation;
-   nullable Player support;
-   deterministic event history;
-   atomic score + event transaction;
-   concurrency-safe score increment.

Checkpoint validation passed.

## M7-C --- Socket.IO --- PASS

Implemented:

``` text
scoring_event:created
game:score_updated
```

Validated:

-   payloads;
-   post-commit behavior;
-   canonical event ordering;
-   failed-mutation event suppression;
-   M3--M6 event regression;
-   reconnect;
-   concurrent scoring/event delivery.

Final M7-C result:

``` text
68 passed
0 failed
```

Concurrency evidence:

``` text
Requests:                       10
Successful:                     10
Score delta:                    10
ScoringEvent DB delta:          10
scoring_event:created received: 10
game:score_updated received:    10
Lost increments:                 0
Lost M7 events:                  0
```

## M7-D --- Client / Docs / Regression --- LOCAL PASS

Implemented/prepared:

-   technical `/client` display for M7 events;
-   final `scripts/validate_m7.sh`;
-   M7 architecture documentation;
-   Game documentation;
-   Socket.IO documentation;
-   Devin validation prompt;
-   DeepSeek review prompt;
-   handoff / implementation-map refresh.

Final local cumulative validation:

``` text
M7 VALIDATION PASSED
Passed: 127
Failed: 0
```

M6 regression remains:

``` text
57 passed
0 failed
```

Alembic:

``` text
20260813_0004 (head)
```

------------------------------------------------------------------------

# 12. Technical Validation Client

`/client` remains a diagnostic development tool, not a production
scoreboard.

It displays existing connection and M3--M6 domain behavior plus:

``` text
scoring_event:created
game:score_updated
```

Useful M7 display includes:

-   event ID;
-   Game ID;
-   Team ID;
-   nullable Player ID;
-   event type;
-   created timestamp;
-   home score;
-   away score.

------------------------------------------------------------------------

# 13. Validation Assets

Preserve:

``` text
scripts/validate_m6.sh
scripts/validate_m7a.sh
scripts/validate_m7b.sh
scripts/validate_m7c.sh
```

Final current-M7 harness:

``` text
scripts/validate_m7.sh
```

`validate_m7.sh` validates current final behavior and preserves M6
regression. It must not treat checkpoint-only expectations that became
intentionally obsolete as final architecture requirements.

------------------------------------------------------------------------

# 14. Protected M0--M6 Behavior

M7 must not break:

``` text
Docker startup
Render startup
PostgreSQL
Alembic history
health/live
health/ready
info
Game CRUD
Team CRUD
Player CRUD
Team roster retrieval/order/isolation
Socket.IO connection
Socket.IO acknowledgement
Team events
Game events
Player events
roster:updated invalidation
disconnect/reconnect
```

------------------------------------------------------------------------

# 15. Explicitly Out of Scope

M7 does not implement:

``` text
Game clock
Timer persistence
Periods / halves
Halftime
Game completion workflow
Score correction
Goal deletion
Goal undo
Assists
Cards
Substitutions
Lineups
Player statistics
Team statistics
Shot tracking
Possession
Authentication
Authorization
Users
Organizations
Seasons
Tournament structure
Redis
NATS
Kafka
Microservices
OBS scoreboard
Production scoreboard UI
```

------------------------------------------------------------------------

# 16. Current Completion Gate

As of the latest local validation:

``` text
M7-A PASS
M7-B PASS
M7-C PASS
M7-D LOCAL PASS
Local cumulative regression PASS — 127/127
Alembic local head PASS — 20260813_0004
```

Still required before M7 may be marked **COMPLETE**:

``` text
DeepSeek independent review
        ↓
Resolve any legitimate BLOCKER / REQUIRED FIX
        ↓
GPT production-deployment approval
        ↓
GitHub push
        ↓
Render deployment
        ↓
Production cumulative M7 validation
        ↓
Final AI_HANDOFF.md production-state confirmation
        ↓
Final IMPLEMENTATION_MAP.md production-state confirmation
        ↓
Commit documentation
```

Only then may M8 begin.

------------------------------------------------------------------------

# 17. DeepSeek Review Standard

Review:

-   migration safety;
-   Game ORM/schema alignment;
-   ScoringEvent ORM/schema alignment;
-   transaction atomicity;
-   concurrency correctness;
-   Team/Game validation;
-   Player/Team validation;
-   REST behavior;
-   history ordering;
-   Socket.IO payloads;
-   post-commit event ordering;
-   failed-mutation event suppression;
-   validation harness quality;
-   M0--M6 regression risk;
-   security;
-   documentation;
-   scope control.

Classify findings only as:

``` text
BLOCKER
REQUIRED FIX
OPTIONAL IMPROVEMENT
```

Architecture preference alone is not a required fix.

------------------------------------------------------------------------

# 18. Expected End State

After production validation, ScoreStreamLive can truthfully state:

> A valid scoring action becomes durable Game score state and durable
> scoring history in one concurrency-safe PostgreSQL transaction, and
> connected clients are notified only after that state commits.

That is the complete architectural goal of M7.
