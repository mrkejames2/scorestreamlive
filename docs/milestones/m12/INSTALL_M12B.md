# ScoreStreamLive M12-B Installation

Replace:

```text
templates/games/index.html
static/css/games.css
static/js/games/index.js
```

Add:

```text
scripts/validate_m12b.sh
M12B_HUMAN_ACCEPTANCE.md
M12B_RELEASE_NOTES.md
```

No router, database, migration, or backend service changes are required.

Rebuild:

```bash
chmod +x scripts/validate_m12b.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

Validate:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m12b.sh
```

Then hard-refresh `/games` in Chrome with:

```text
Command + Shift + R
```

Human test:
1. Click New Game.
2. Enter a Game Name.
3. Search/select Home Team.
4. Search/select Away Team.
5. Verify same Team cannot be used twice.
6. Create the Game.
7. Verify it appears in the recent Games list.
