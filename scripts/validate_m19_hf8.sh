#!/usr/bin/env bash
set -euo pipefail
grep -q 'advertisement_artwork_id' app/models/game.py
grep -q 'advertisement/artwork-selection' app/api/game_advertisement.py
grep -q 'Game.advertisement_artwork_id==a.id' app/api/broadcast_artwork.py
grep -q 'createArtworkPicker' static/js/games/game-advertisement-m19hf2.js
grep -q 'm19hf8-1' templates/games/detail.html
grep -q 'revision="20261001_0036"' alembic/versions/20261001_0036_advertisement_artwork_library.py
echo 'M19 HF8 static validation: PASS'
