# M19 Advertisement Broadcast Scene Hotfix

Adds `Intro | Live | Advertisement | Summary | Thank You`.

Advertisement is one per-game PNG/JPEG/WebP image, managed from Game Detail and selected from Control Center. It uses the existing `GAME_INTRO_STORAGE_DIR`, so production uses the existing persistent `/var/data/game-intros` storage. The stable `/stream/games/{game_id}` URL is unchanged. Intro, Advertisement, and Thank You broadcast image URLs are cache-versioned from their `updated_at` timestamps.

Apply from repo root after creating the hotfix branch:

    python3 scripts/apply_m19_advertisement_hotfix.py

Then inspect the diff, rebuild, validate Alembic/health, and perform manual browser/Streamlabs testing before commit/push.
