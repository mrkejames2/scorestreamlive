#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
cd "$PROJECT_ROOT"

python3 - <<'PY'
from pathlib import Path

root = Path.cwd()

def read_required(rel):
    path = root / rel
    if not path.exists():
        raise SystemExit(f"M12-E patch failed: missing {rel}")
    return path, path.read_text()

def write_if_changed(path, old_text, new_text):
    if new_text != old_text:
        path.write_text(new_text)
        print(f"[PATCH] {path.relative_to(root)}")
    else:
        print(f"[SKIP] {path.relative_to(root)}: already integrated")

# ------------------------------------------------------------
# 1. app/main.py — register M12-E web router
# ------------------------------------------------------------
path, text = read_required("app/main.py")
original = text

import_line = "from app.web.game_setup import router as game_setup_web_router"
if import_line not in text:
    anchor = "from app.web.games import router as games_web_router"
    if anchor not in text:
        raise SystemExit(
            "M12-E patch failed: could not find "
            "'from app.web.games import router as games_web_router' in app/main.py"
        )

    text = text.replace(
        anchor,
        anchor + "\n" + import_line,
        1,
    )

include_line = "app.include_router(game_setup_web_router)"
if include_line not in text:
    anchor = "app.include_router(games_web_router)"
    if anchor not in text:
        raise SystemExit(
            "M12-E patch failed: could not find "
            "'app.include_router(games_web_router)' in app/main.py"
        )

    text = text.replace(
        anchor,
        anchor + "\n" + include_line,
        1,
    )

write_if_changed(path, original, text)

# ------------------------------------------------------------
# 2. templates/games/index.html — add Manage Roster action
# ------------------------------------------------------------
path, text = read_required("templates/games/index.html")
original = text

setup_link = '<a class="button button-secondary setup-link">Manage Roster</a>'

if setup_link not in text:
    anchor = '<a class="button button-primary control-link">Open Control Center</a>'

    if anchor not in text:
        raise SystemExit(
            "M12-E patch failed: Control Center action anchor "
            "not found in templates/games/index.html"
        )

    text = text.replace(
        anchor,
        setup_link + "\n          " + anchor,
        1,
    )

write_if_changed(path, original, text)

# ------------------------------------------------------------
# 3. static/js/games/index.js — bind setup URL
# ------------------------------------------------------------
path, text = read_required("static/js/games/index.js")
original = text

setup_binding = 'fragment.querySelector(".setup-link").href'

if setup_binding not in text:
    anchor = 'fragment.querySelector(".control-link").href ='

    index = text.find(anchor)
    if index < 0:
        raise SystemExit(
            "M12-E patch failed: Control Center JS binding anchor "
            "not found in static/js/games/index.js"
        )

    insertion = (
        'fragment.querySelector(".setup-link").href =\n'
        '    `/games/${game.id}/setup`;\n\n'
        '  '
    )

    text = text[:index] + insertion + text[index:]

write_if_changed(path, original, text)

print("========================================")
print("M12-E integration patch complete")
print("========================================")
PY