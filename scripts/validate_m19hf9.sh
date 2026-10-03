#!/usr/bin/env bash
set -euo pipefail
echo "== M19-HF9 validation =="
python3 -m py_compile app/models/game.py app/schemas/game.py app/services/game_service.py app/api/games.py app/api/control.py
grep -q overlay_theme app/models/game.py
grep -q pink_out app/schemas/game.py
grep -q /overlay-theme app/api/games.py
grep -q overlay-theme-pink-out.css templates/overlay/game.html
grep -q m19hf9-theme-select templates/control/game.html
grep -q updateOverlayTheme static/js/control/api.js
grep -q applyOverlayTheme static/js/overlay/overlay.js
test -f alembic/versions/20261004_0037_add_game_overlay_theme.py
echo "PASS: M19-HF9 static integration checks"
