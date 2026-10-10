#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m compileall -q app/api/game_announcements.py app/models/game_announcement.py app/schemas/game_announcement.py app/services/game_announcement_service.py alembic/versions/20261010_0038_game_announcements.py
python3 - <<'PY'
from pathlib import Path
for name in ["app/main.py","app/models/__init__.py","templates/control/game.html","templates/overlay/game.html"]:
    content = Path(name).read_text()
    assert "hf11" in content or "game_announcement" in content, name
print("HF11 static integration PASS")
PY
if command -v node >/dev/null 2>&1; then
  node --check static/js/control/announcements-hf11.js
  node --check static/js/overlay/announcements-hf11.js
fi
echo "HF11 compile and integration checks PASS"
