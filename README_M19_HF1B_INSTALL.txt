ScoreStreamLive M19 HF1B — Broadcast Summary + Thank You Scenes

Designed for M19-I baseline afe69d375df84fae4ed8d860cc2be68a139e1f8e.
Safe while approved HF1A static/css/overlay-m17g.css remains uncommitted; HF1B does not touch it.

After extracting at repository root, run:
  python3 scripts/apply_m19_hf1b.py

Then STOP and inspect BEFORE rebuild/migration:
  git diff --check
  git status --short
  git diff

Scope:
- Broadcast Scene buttons: Intro / Live / Summary / Thank You
- Stable /stream/games/{game_id} remains the one Streamlabs browser source
- Summary reuses /broadcast/games/{game_id}
- Per-game Thank You upload/enable/remove UI mirrors Intro
- Reuses GAME_INTRO_STORAGE_DIR; no new Render disk/env var
- Adds Alembic 20260921_0032
- Includes cache-bust updates for changed stream/control assets

Do not commit/deploy until migration, upload, four-scene switching, refresh persistence,
and visual testing all pass.
