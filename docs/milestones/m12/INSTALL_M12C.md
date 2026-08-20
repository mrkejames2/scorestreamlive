# Install M12-C

Replace:

```text
templates/games/index.html
static/js/games/index.js
```

Add:

```text
scripts/validate_m12c.sh
M12C_HUMAN_ACCEPTANCE.md
```

`static/css/games.css` does not need to change from M12-B.

Rebuild:

```bash
cd ~/projects/scorestreamlive
chmod +x scripts/validate_m12c.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

Validate:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m12c.sh
```

Then hard-refresh `/games` in Chrome with Command + Shift + R.

Create a new Game through the UI and verify:
- Pregame lifecycle exists.
- Clock is stopped at 0:00.
- Control Center opens.
- Overlay opens.
