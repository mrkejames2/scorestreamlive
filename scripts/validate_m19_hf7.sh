#!/usr/bin/env bash
set -euo pipefail
python3 -m py_compile app/api/game_halftime_slideshow.py app/models/game_halftime_slideshow.py app/services/game_broadcast_presentation_service.py
grep -q '20260930_0035' alembic/versions/20260930_0035_add_halftime_slideshow.py
grep -q 'halftime_slideshow' app/models/game_broadcast_presentation.py
grep -q 'halftime_slideshow' app/services/game_broadcast_presentation_service.py
grep -q 'game_halftime_slideshow_router' app/main.py
grep -q 'm19hf7-show-halftime' templates/control/game.html
grep -q 'halftime-slideshow-scene' templates/stream/game.html
grep -q 'loadHalftimeSlideshow' templates/games/detail.html
echo "M19 HF7 static validation: PASS"
