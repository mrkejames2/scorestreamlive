# ScoreStreamLive M11-B Installation

M11-B turns the M11-A REST-loaded overlay into a live Socket.IO overlay.

## Replace

Copy `overlay.js` to:

```text
static/js/overlay/overlay.js
```

Copy `templates_overlay_game.html` to:

```text
templates/overlay/game.html
```

Add:

```text
scripts/validate_m11b.sh
scripts/create_m11b_demo.sh
M11B_HUMAN_ACCEPTANCE.md
```

The template uses the local Socket.IO browser client already established in M10:

```text
/static/vendor/socket.io.min.js
```

No database migration or backend mutation endpoint is introduced.

## Install

```bash
cp templates_overlay_game.html templates/overlay/game.html
chmod +x scripts/validate_m11b.sh scripts/create_m11b_demo.sh

sudo docker compose down
sudo docker compose up --build -d
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m11b.sh
```

## Human demo

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m11b_demo.sh
```

Open the Control Center and overlay. Do not manually refresh the overlay during the test.
