# M21-F R4 — Single Managed Futsal Team

Baseline: M21-F R3 installed, Alembic 20261016_0042 applied. GitHub feature branch remains the only development branch; do not merge into main or deploy Render.

## Design

- Choose **My Team**, **Opponent**, and **Home/Away** when creating a Futsal game.
- Persist `games.my_team_id`; it must match one of the game's two teams. Soccer games leave it null.
- Only My Team loads a roster and allows player attribution. Opponent scoring is a team goal, without requiring a roster.
- Existing Futsal games can have My Team assigned on the Futsal Games page; existing goals are preserved.
- Existing shared `/teams/{team_id}` roster editor remains authoritative.
- Goal countdown and period snapshots from R3 remain unchanged.

## Install (DevOps1, local only)

1. Back up the local database.
2. Unzip this archive in the repository root and run `python3 scripts/apply_m21f_r4.py`.
3. Run `git diff --check` and `python3 -m compileall -q app`.
4. Run `sudo docker compose up -d --build`.
5. Run `sudo docker compose exec app alembic upgrade head` and verify `alembic current`.
6. Hard-refresh the Futsal Games and Futsal Control Center pages.

## Acceptance

1. Create a new Futsal game with My Team as Home, and verify only Home has roster selector.
2. Create another with My Team as Away, and verify only Away has roster selector.
3. Record goals for both sides. My Team can use a named scorer; opponent always uses team goal.
4. Assign My Team to an existing pre-R4 game and verify its roster loads without resetting goals.
5. Confirm goal corrections and removals, period and countdown, and mobile layout.
6. Confirm Soccer games and Control Center still function.

**Known limitation:** Existing games have no My Team selection until explicitly assigned. This migration does not infer a selection. Opponent is still represented by a Team record for name/logo/score, not a separate free-text placeholder. This package does not modify backend scoring authorization to reject direct API player attribution for opponent goals; it enforces the simplified workflow in the Futsal UI.
