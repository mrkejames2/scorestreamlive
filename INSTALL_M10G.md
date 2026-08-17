# ScoreStreamLive M10-G Installation

## Replace / add

```text
templates/control/game.html
static/css/control.css
static/js/control/control.js

scripts/create_m10g_demo.sh
scripts/validate_m10g.sh
```

This package also includes the current regression validators so a clean
checkout can run the complete M10-G -> M10-F -> ... chain.

## Rebuild

Static/template files are copied into the Docker image:

```bash
chmod +x scripts/validate_m10*.sh
chmod +x scripts/create_m10g_demo.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m10g.sh
```

Expected:

```text
M10-G VALIDATION PASSED
```

## Fresh human checkpoint game

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m10g_demo.sh
```

Open the printed Control Center URL first on the iPhone benchmark, then on
the tablet.

Do not start M10-H until the M10-G human acceptance checklist is complete.
