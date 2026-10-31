"""Idempotently register M21-C routes in app/main.py."""
from pathlib import Path
p=Path('app/main.py')
s=p.read_text()
api='from app.api.futsal_clock import router as futsal_clock_router'
web='from app.web.futsal_clock import router as futsal_clock_web_router'
if api not in s:
    marker='from app.api.game_clock import router as game_clock_router'
    if marker not in s: raise SystemExit('Cannot find game clock import in app/main.py')
    s=s.replace(marker,marker+'\n'+api,1)
if web not in s:
    marker='from app.web.games import router as games_web_router'
    if marker not in s: raise SystemExit('Cannot find games web import in app/main.py')
    s=s.replace(marker,marker+'\n'+web,1)
if 'app.include_router(futsal_clock_router)' not in s:
    marker='app.include_router(game_clock_router)'
    if marker not in s: raise SystemExit('Cannot find game clock router registration')
    s=s.replace(marker,marker+'\napp.include_router(futsal_clock_router)',1)
if 'app.include_router(futsal_clock_web_router)' not in s:
    marker='app.include_router(games_web_router)'
    if marker not in s: raise SystemExit('Cannot find games web router registration')
    s=s.replace(marker,marker+'\napp.include_router(futsal_clock_web_router)',1)
p.write_text(s)
print('M21-C routes registered in app/main.py')
