# M12-D4 — Branded Game Setup + Game Management

## Replace

```text
templates/games/index.html
static/js/games/index.js
```

## Add

```text
static/css/games-d4.css
scripts/validate_m12d4.sh
```

No backend, database, Alembic, or upload changes are required.

D4 consumes Team branding already established by D1-D3:

```text
logo_url
primary_color
secondary_color
```

## Rebuild

```bash
cd ~/projects/scorestreamlive
chmod +x scripts/validate_m12d4.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m12d4.sh
```

## Human acceptance

Hard refresh `/games` using Command + Shift + R.

Verify:

1. Existing branded Teams show logo/initials and color swatches in Team search.
2. Selecting a branded Home Team shows its branding beside the selected label.
3. Selecting a branded Away Team shows its branding beside the selected label.
4. A Team without a logo falls back to initials instead of a broken image.
5. Existing/newly-created Games show both Team logos/initials on the game card.
6. Team primary colors visually accent the game card.
7. Existing New Game / inline Team creation still works.
8. Creating a Game still initializes Pregame + stopped 0:00.
9. Control Center and Overlay links still open.

D4 intentionally does not add branding to Control Center or Overlay; those are
D5 and D6.
