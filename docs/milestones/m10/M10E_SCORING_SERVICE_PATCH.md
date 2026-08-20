# Required scoring-service integration

This cleanup intentionally does **not** replace `app/services/scoring_service.py`
because that backend file was not part of the supplied M10-E artifact package.

The scoring service must set `ScoringEvent.game_elapsed_seconds` **on the server**
inside the same scoring transaction.

## Rule

Immediately before constructing the `ScoringEvent`, obtain the authoritative
GameClock for `data.game_id` and compute the current elapsed seconds using the
same M8 clock semantics already used by the clock API.

Conceptually:

```python
now = datetime.now(timezone.utc)

elapsed = clock.elapsed_seconds

if clock.status == "running" and clock.running_since is not None:
    elapsed += max(
        0,
        int((now - clock.running_since).total_seconds()),
    )

scoring_event = ScoringEvent(
    game_id=data.game_id,
    team_id=data.team_id,
    player_id=data.player_id,
    event_type=data.event_type,
    game_elapsed_seconds=elapsed,
    created_at=now,
)
```

### Important

- Do not accept `game_elapsed_seconds` from the browser.
- Do not derive it from `created_at` in JavaScript.
- Do not add per-second database writes.
- Reuse the existing M8 authoritative elapsed-time helper if the service layer
  already exposes one. That is preferred over duplicating the formula above.
- Preserve the existing atomic score increment and single transaction.
- `scoring_event:created` should naturally include the field because the
  response schema now exposes it.
- Historical rows remain `NULL`; the UI displays `—` rather than inventing a
  match minute.

This is the only backend integration point required beyond the supplied model,
schema, and migration.
