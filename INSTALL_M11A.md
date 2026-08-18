# ScoreStreamLive M11-A Installation

M11-A adds the first broadcast overlay shell.

## Files

Replace:

```text
app/api/control.py
```

Add:

```text
templates/overlay/game.html
static/css/overlay.css
static/js/overlay/overlay.js
scripts/validate_m11a.sh
scripts/create_m11a_demo.sh
```

No database migration is introduced.

## Important Docker note

Your Docker image must already copy `templates/` and `static/` into the image, as established during M10.

Rebuild:

```bash
chmod +x scripts/validate_m11a.sh
chmod +x scripts/create_m11a_demo.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m11a.sh
```

## Create the human demo

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m11a_demo.sh
```

Open the printed overlay URL in a browser. It is also suitable as an OBS/Streamlabs Browser Source.

M11-A deliberately loads authoritative REST state only on page load. Change the Control Center, then refresh the overlay to verify the new authoritative score/phase/clock. M11-B adds Socket.IO live synchronization.
