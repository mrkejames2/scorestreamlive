# M21-G-A — Canonical Sport Routes (local validation only)

## Scope
- Adds canonical Soccer pages `/soccer/games`, `/soccer/teams`, `/soccer/teams/{id}`, `/soccer/games/{id}`, `/soccer/games/{id}/setup`, `/soccer/games/{id}/control`, `/soccer/games/{id}/overlay`, `/soccer/games/{id}/stream`.
- Adds `/futsal/teams` (temporary redirect to existing Futsal team section), `/futsal/teams/{id}`, `/futsal/games/{id}/overlay`, `/futsal/games/{id}/stream` (temporary redirect to Futsal overlay).
- Existing `/futsal/games`, `/futsal/games/{id}/control`, `/futsal/games/{id}/clock` remain canonical and unchanged.
- Sport switch now targets `/soccer/games` rather than `/games`.
- All old routes stay live. No database migration, no changed API paths, no rewritten broadcast/OBS/Streamlabs URLs.
- Canonical game routes check sport and, for authenticated operator pages, existing game permission. Canonical team detail checks same club and sport.

## Install
```
cd ~/projects/scorestreamlive
git switch feature/m21-a-multisport-foundation
# Copy ZIP into repository root, then:
unzip -o ScoreStreamLive_M21-G-A.zip
python3 scripts/apply_m21g_a.py
python3 scripts/apply_m21g_a.py  # idempotence check
python3 -m compileall -q app
 git diff --check
sudo docker compose up -d --build
```
No Alembic migration required.

## Validate
1. Log in, visit `/sports`, select Soccer: expected `/soccer/games`. Select Futsal: expected `/futsal/games`.
2. Visit `/soccer/teams`, `/soccer/teams/<soccer-team-uuid>`, `/futsal/teams/<futsal-team-uuid>`.
3. Visit `/soccer/games/<soccer-game-uuid>/control` and `/futsal/games/<futsal-game-uuid>/control`.
4. Cross-sport test: `/soccer/games/<futsal-game-uuid>/control` and `/futsal/games/<soccer-game-uuid>/overlay` must return 404.
5. Confirm `/games`, `/teams`, `/control/games/<soccer-game-uuid>`, `/stream/games/<soccer-game-uuid>`, and `/futsal/overlay/games/<futsal-game-uuid>` continue to work.
6. Test OBS/Streamlabs browser-source URLs unchanged; test the app's current Soccer Games and Futsal Games links for legacy navigation.
7. `git status --short` and review diff before any commit.

## Deliberately deferred to M21-G-B/C
- Soccer's embedded JavaScript still uses some legacy `/games` and `/teams` links; these remain functional. Full internal link migration requires auditing all templates and JS in G-B/C.
- Futsal `/futsal/teams` temporarily redirects to the Futsal game page team panel. A dedicated sport-aware teams index is G-C.
- The Futsal Games dashboard visual redesign is G-B.
- Future Bowling URLs are a documented convention, not routes yet.
- Canonical `/futsal/games/{id}/stream` currently redirects to the Futsal overlay; it is **not** a finished broadcast-scene page.
- Public canonical overlays are intentionally unauthenticated, like existing broadcast overlays. Never expose private team data through them.

## Compatibility
This installer expects the M21-A web router in `app/web/games.py` and M21-A registration in `app/main.py`. It is additive and does not depend on M21-F R4 implementation details. Fail-closed if upstream anchors differ. Validate on local feature branch; do not merge or deploy before M21-G-F signoff.
