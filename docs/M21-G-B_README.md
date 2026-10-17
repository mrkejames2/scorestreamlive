# M21-G-B — Unified Futsal Games Dashboard

## Scope
Visual and navigation polish for `/futsal/games`, using Soccer's existing `games.css` design language. Keeps the M21-F R4 My Team workflow and backend API. No database migration or Soccer template changes.

## Requirements
M21-F R4 and M21-G-A installed on `feature/m21-a-multisport-foundation`.

## Install
```bash
cd ~/projects/scorestreamlive
unzip -o ScoreStreamLive_M21-G-B.zip
python3 scripts/apply_m21g_b.py
git diff --check
sudo docker compose up -d --build
```

## Validate
1. `/futsal/games` loads styled cards, counters, filter, responsive layout.
2. New Game opens panel; My Team/Opponent/Home-Away selectors appear (R4).
3. Create game, verify `/futsal/games/{id}/control` works and My Team persists.
4. Existing Futsal Game — My Team assignment still works within New Game panel.
5. Create Team and Refresh work; `/futsal/teams` redirects to team form.
6. Overlay link opens `/futsal/games/{id}/overlay`.
7. `/soccer/games` is visually/functionally unchanged.
8. Test on phone/tablet viewport.

## Safety
Installer refuses to overwrite unexpected templates, saves `templates/sports/futsal_games.html.before-m21gb`. Does not push, merge or deploy production. Untracked backup should not be committed.

## Known limitations
The existing R4 workflow still requires selecting an opponent Team record. Team management UI is M21-G-C. Match display currently shows game name and Home/Away labels; additional team logo branding comes later. Status counters depend on existing game statuses.
