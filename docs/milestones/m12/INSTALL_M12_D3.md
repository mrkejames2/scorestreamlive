# M12-D3 — Inline Team Creation + Branding UI

## Replace

```text
templates/games/index.html
static/js/games/index.js
```

## Add

```text
static/css/games-d3.css
scripts/validate_m12d3.sh
```

No backend or Alembic changes are required.

M12-D3 consumes the existing:

```text
POST /api/teams
POST /api/teams/{team_id}/logo
```

contracts established in D1/D2.

## Rebuild

```bash
cd ~/projects/scorestreamlive
chmod +x scripts/validate_m12d3.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m12d3.sh
```

## Human acceptance

Hard refresh `/games` using Command + Shift + R.

Verify both Home and Away flows:

1. Click New Game.
2. Click `+ Create New Home Team`.
3. Enter a Team Name and Short Name.
4. Choose Primary and Secondary colors.
5. Select PNG/JPEG/WebP logo smaller than 2 MB.
6. Verify the logo preview appears before upload.
7. Click `Create + Select Home Team`.
8. Verify the new Team immediately becomes the selected Home Team.
9. Repeat for Away Team.
10. Create the Game.
11. Verify the Game initializes to Pregame / stopped 0:00.
12. Verify the Game opens successfully in Control Center and Overlay.

D3 does not yet add logo presentation to the game list/control/overlay. Those
presentation integrations are D4-D6.
