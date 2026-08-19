#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
cd "$PROJECT_ROOT"

python3 - <<'PY'
from pathlib import Path

root = Path.cwd()

def required(rel):
    path = root / rel
    if not path.exists():
        raise SystemExit(f"M12-F patch failed: missing {rel}")
    return path, path.read_text()

def save(path, old, new):
    if old == new:
        print(f"[SKIP] {path.relative_to(root)}")
    else:
        path.write_text(new)
        print(f"[PATCH] {path.relative_to(root)}")

# app/main.py
path, text = required("app/main.py")
old = text

import_line = "from app.web.game_detail import router as game_detail_web_router"
if import_line not in text:
    anchor = "from app.web.game_setup import router as game_setup_web_router"
    if anchor not in text:
        raise SystemExit("M12-F patch failed: M12-E game_setup router import missing")
    text = text.replace(anchor, anchor + "\n" + import_line, 1)

include_line = "app.include_router(game_detail_web_router)"
if include_line not in text:
    anchor = "app.include_router(game_setup_web_router)"
    if anchor not in text:
        raise SystemExit("M12-F patch failed: M12-E game_setup router include missing")
    text = text.replace(anchor, anchor + "\n" + include_line, 1)

save(path, old, text)

# Game Management card: add Open Game before Manage Roster.
path, text = required("templates/games/index.html")
old = text
hub_link = '<a class="button button-primary hub-link">Open Game</a>'

if hub_link not in text:
    anchor = '<a class="button button-secondary setup-link">Manage Roster</a>'
    if anchor not in text:
        raise SystemExit("M12-F patch failed: M12-E Manage Roster action missing")
    text = text.replace(anchor, hub_link + "\n          " + anchor, 1)

save(path, old, text)

# Game Management JS: bind Open Game.
path, text = required("static/js/games/index.js")
old = text
binding = 'fragment.querySelector(".hub-link").href'

if binding not in text:
    anchor = 'fragment.querySelector(".setup-link").href ='
    idx = text.find(anchor)
    if idx < 0:
        raise SystemExit("M12-F patch failed: M12-E setup-link binding missing")

    insertion = (
        'fragment.querySelector(".hub-link").href =\n'
        '    `/games/${game.id}`;\n\n'
        '  '
    )
    text = text[:idx] + insertion + text[idx:]

save(path, old, text)

# M12-E roster page: add navigation back to Game Hub.
path, text = required("templates/games/setup.html")
old = text
game_hub = '<a class="button button-secondary" href="/games/{{ game_id }}">Game Hub</a>'

if game_hub not in text:
    anchor = '<a class="button button-secondary" href="/games">Back to Games</a>'
    if anchor not in text:
        raise SystemExit("M12-F patch failed: Back to Games anchor missing in setup.html")
    text = text.replace(anchor, game_hub + "\n        " + anchor, 1)

save(path, old, text)

print("========================================")
print("M12-F integration patch complete")
print("========================================")
PY
