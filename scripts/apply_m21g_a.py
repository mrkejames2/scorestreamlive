#!/usr/bin/env python3
"""Additive, idempotent M21-G-A route installer. Run from repo root."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
main = root / 'app/main.py'
games = root / 'app/web/games.py'
module = root / 'app/web/sport_routes_m21ga.py'
if not all(p.exists() for p in (main, games, module)):
    sys.exit('ERROR: Run from the ScoreStreamLive repo root after unzipping; required source files missing')

m = main.read_text()
imp = 'from app.web.sport_routes_m21ga import router as sport_routes_m21ga_router\n'
registration = 'app.include_router(sport_routes_m21ga_router)\n'
if imp not in m:
    anchor = 'from app.web.games import router as games_web_router\n'
    if m.count(anchor) != 1:
        sys.exit('ERROR: expected app/main.py web games import not found exactly once')
    m = m.replace(anchor, anchor + imp, 1)
if registration not in m:
    anchor = 'app.include_router(games_web_router)\n'
    if m.count(anchor) != 1:
        sys.exit('ERROR: expected app/main.py games router registration not found exactly once')
    m = m.replace(anchor, anchor + registration, 1)

g = games.read_text()
old = 'SPORT_URLS = {"soccer": "/games", "futsal": "/futsal/games"}'
new = 'SPORT_URLS = {"soccer": "/soccer/games", "futsal": "/futsal/games"}'
if old in g:
    g = g.replace(old, new, 1)
elif new not in g:
    sys.exit('ERROR: SPORT_URLS changed upstream; refusing to guess')
# Avoid half-apply when an upstream guard failed.
main.write_text(m)
games.write_text(g)
print('M21-G-A applied: canonical sport pages registered; sport switch points to /soccer/games')
print('Legacy browser URLs and all API/stream routes remain untouched.')
