# M21-G-C — Sport-aware Teams & Rosters

Baseline: feature/m21-a-multisport-foundation commit de0bdb2. Local-only installer; no migrations, no deployment.

## Install

From repository root:

```bash
unzip -o ScoreStreamLive_M21-G-C.zip
python3 scripts/apply_m21g_c.py
git diff --check
sudo docker compose up -d --build
```

## Test

1. `/futsal/teams`: sidebar, only futsal teams, create/edit futsal team and logo, open roster, add/edit player.
2. `/soccer/teams`: only soccer teams; create/edit soccer team; open roster.
3. `/futsal/games`: My Team Roster link for games with `my_team_id`; return to game control.
4. `/teams` and `/teams/{id}` legacy pages continue working.
5. Check 404 on cross-sport canonical team UUIDs; check mobile menu and role/club isolation.

Installer creates `.before-m21gc` backups alongside modified files. Do not commit backups. No automatic merge or Render deployment.
