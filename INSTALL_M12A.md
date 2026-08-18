# ScoreStreamLive M12-A Installation

M12-A adds a read-only Game Management Home at:

```text
/games
```

It uses existing APIs only.

## Add these files

```text
app/web/__init__.py
app/web/games.py
templates/games/index.html
static/css/games.css
static/js/games/index.js
scripts/validate_m12a.sh
scripts/create_m12a_demo.sh
```

## Register the router in `app/main.py`

Add this import with the other router imports:

```python
from app.web.games import router as games_web_router
```

Then, after the FastAPI application object is created and alongside the other
`include_router(...)` calls, add:

```python
app.include_router(games_web_router)
```

Do not add an `/api` prefix. The page route is intentionally `/games`.

## Rebuild

```bash
chmod +x scripts/validate_m12a.sh
chmod +x scripts/create_m12a_demo.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m12a.sh
```

## Human demo

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m12a_demo.sh
```

Then open:

```text
http://192.168.12.133:8000/games
```

M12-A is read-only. Game/team creation through this UI is intentionally deferred
to later M12 checkpoints.
