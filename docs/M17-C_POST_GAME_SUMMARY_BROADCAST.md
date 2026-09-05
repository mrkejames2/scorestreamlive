# M17-C — Post-Game Summary & Broadcast Scene

## Objective

Provide a public, unauthenticated, read-only Game summary and a fixed 1280×720
broadcast scene backed by authoritative PostgreSQL state.

## Public surfaces

- `GET /api/public/games/{game_id}/summary`
- `GET /summary/games/{game_id}`
- `GET /broadcast/games/{game_id}`

Active and archived Games remain readable. Hard-deleted or unknown Games return
404.

## Authority

- `Game.home_score` / `Game.away_score` are authoritative scores.
- `GameLifecycle.phase == full_time` is the sole FINAL marker.
- Goal history is projected from current authoritative `ScoringEvent` rows.
- Scorer corrections therefore replace the displayed scorer naturally.
- Deleted goals disappear naturally.
- Match chronology is `game_elapsed_seconds ASC NULLS LAST`, then
  `created_at ASC`, then `id ASC`.
- Match minute is `floor(game_elapsed_seconds / 60) + 1`.
- Missing scorer is displayed as `Unknown scorer`.
- Missing authoritative elapsed time displays no invented minute.

## Public data boundary

The summary projection exposes only:
- Game display name, schedule, score, phase/final state, archived state
- Team name, short name, logo, and presentation colors
- Goal team side, scorer display name, jersey number, match elapsed seconds/minute

It does not expose Club membership, roles, assignments, sessions, users, request
IDs, emails, or other private administrative data.

## Socket behavior

The browser joins the existing public Game room using Socket.IO handshake auth:

- `game_id=<game UUID>`
- `audience=overlay`

Socket events are refresh signals only. The client reloads the authoritative
public summary endpoint and never reconstructs domain truth from socket payloads.

A 20-second safety refresh and visibility refresh provide recovery.

## Database

No M17-C migration is required.

## Validation

M17-C adds regression domain:

`Post-Game Summary & Broadcast Scene`

Expected cumulative result after implementation:

- FAST: 28/28 PASS
- FULL: 28/28 PASS
- Human Acceptance: PASS
