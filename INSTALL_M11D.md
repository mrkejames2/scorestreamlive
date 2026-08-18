# ScoreStreamLive M11-D Installation

M11-D upgrades only the broadcast presentation layer.

## Replace

```text
templates/overlay/game.html
static/css/overlay.css
static/js/overlay/overlay.js
```

## Add

```text
scripts/validate_m11d.sh
scripts/create_m11d_demo.sh
M11D_HUMAN_ACCEPTANCE.md
M11D_RELEASE_NOTES.md
```

No database migration or backend/domain change is introduced.

## Rebuild

```bash
chmod +x scripts/validate_m11d.sh
chmod +x scripts/create_m11d_demo.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m11d.sh
```

## Human demo

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m11d_demo.sh
```

For human acceptance, test the overlay at 1280x720 first because that is the current phone-stream benchmark.
