# M21-D: Futsal broadcast overlay (validation candidate)

Base: `feature/m21-a-multisport-foundation` through commit `ca122f5`.

## Scope
- New read-only Futsal broadcast overlay at `/futsal/overlay/games/<uuid>`.
- Transparent 1280×720 coordinate space; home/away logos, colors, scores; countdown from server-authoritative clock snapshot; phase display; optional sponsor artwork.
- Refreshes snapshot every five seconds; local monotonic countdown rendering between refreshes.
- Existing `/overlay/games/<uuid>` (Soccer) is unchanged.
- No Alembic migration.

## Installation on DevOps1
From `~/projects/scorestreamlive` (ZIP downloaded to same directory):

```bash
unzip -o ScoreStreamLive_M21-D.zip
python3 scripts/apply_m21d.py
git diff --check
sudo docker compose up -d --build
sudo docker compose ps
```

## Validation
Open `http://127.0.0.1:8000/futsal/overlay/games/9ee3d5d5-70d3-42a7-92af-3793c71bd263`.
Verify score/team names, countdown, refresh persistence, OBS/Streamlabs transparent background, and that existing Soccer overlay is unchanged.

**Notes:** Public overlay data depends on `BROADCAST_OVERLAY` entitlement (same as Soccer). The phase is sourced from existing lifecycle state, not M21-C Futsal period config, so the half label may need refinement during M21-E. The sponsor rotation here is a basic fallback, not yet feature parity with Soccer's presentation controller. This is a review/test candidate, not a PASS claim.

No GitHub push, main merge, or Render deployment is performed.
