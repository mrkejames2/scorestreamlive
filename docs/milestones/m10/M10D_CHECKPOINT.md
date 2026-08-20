# ScoreStreamLive M10-D Checkpoint

## Goal
Add the first scoring mutation controls to the visual Control Center without changing the proven M7 scoring engine.

## Architecture preserved
- PostgreSQL remains authoritative.
- REST remains the mutation boundary.
- M10-D POSTs to the existing `/api/scoring-events` endpoint.
- `Game.home_score` / `Game.away_score` remain authoritative current score.
- `ScoringEvent` remains scoring history.
- Existing `scoring_event:created` and `game:score_updated` events drive live UI synchronization.
- No client-side score arithmetic is authoritative.
- No per-second database writes or `clock:tick` architecture.
- M9 lifecycle/clock optimistic concurrency behavior is unchanged.

## M10-D UI scope
- Home goal control.
- Away goal control.
- Roster scorer selection.
- Nullable scorer (`Team Goal / Unknown Scorer`).
- Scoring controls enabled only during `first_half` and `second_half` and while Socket.IO is connected.
- Existing live score/history rendering remains the display path.

## Explicitly out of scope
- Undo/delete goal.
- Manual score correction.
- Yellow/red cards.
- Substitutions.
- Assists.
- Authentication/permissions.
- OBS/stream overlay (future milestone).
- Backend schema/service changes.

## Acceptance gate
`validate_m10d.sh` must pass, including its M10-C -> M10-B -> M10-A -> M9 regression chain, before M10-D is declared complete.
