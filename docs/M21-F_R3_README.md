# M21-F R3 — shared rosters, mobile controls, durable futsal goal times

**Prerequisites:** M21-E, M21-F, and M21-F R2 installed and validated locally. Feature branch commit 2485872 is the original M21-E baseline. No main/Render push.

## Install

From the repo root:

```bash
unzip -o ScoreStreamLive_M21-F_R3.zip
python3 scripts/apply_m21f_r3.py
python3 -m compileall -q app
sudo docker compose up -d --build
sudo docker compose exec app alembic upgrade head
sudo docker compose exec app alembic current
```

**Database migration required:** revision `20261016_0042`, adds two nullable columns to scoring_events. Run migration before recording new goals. Older goals deliberately show 'Goal time unavailable (recorded before R3)' rather than an inferred, potentially incorrect half. New futsal goals store period and countdown seconds in the same scoring transaction; soccer goals retain NULL fields. Resetting or changing halves does not rewrite historical goal times.

## Validate

1. `/futsal/games` -> Teams & Rosters -> choose a Futsal team -> existing `/teams/{id}` roster editor. Add a player, then reload Futsal Control Center.
2. Select that player in Home/Away scorer dropdown, add a goal. Check scoring history and persisted scorer.
3. Pause clock, score another goal; confirm remaining time doesn't change while paused.
4. Advance to second half, score again; confirm `2nd Half · MM:SS remaining`, and first-half history remains unchanged.
5. Change scorer and remove goal; verify score, overlay and history.
6. Test at 375px phone portrait, tablet portrait/landscape, desktop. Check no horizontal scroll and touch targets.
7. Open `/control/games/{futsal_uuid}` and confirm Futsal redirect; regression-test a Soccer game.

**Limitations:** halftime/full-time lifecycle and complete match end state still require validation; do not mark M21-F production PASS until resolved. No automatic migration of historical futsal goals because their half cannot be reliably reconstructed.
