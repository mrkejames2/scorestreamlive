"""Idempotently register M21-E routers in app/main.py; no compile step needed."""
from pathlib import Path
p=Path('app/main.py')
if not p.exists(): raise SystemExit('Run from repository root')
s=p.read_text()
for marker, addition in [
 ('from app.api.futsal_clock import router as futsal_clock_router', 'from app.api.futsal_rules import router as futsal_rules_router'),
 ('from app.web.futsal_clock import router as futsal_clock_web_router','from app.web.futsal_controls import router as futsal_controls_web_router'),
 ('app.include_router(futsal_clock_router)','app.include_router(futsal_rules_router)'),
 ('app.include_router(futsal_clock_web_router)','app.include_router(futsal_controls_web_router)')]:
 if addition not in s:
  if marker not in s: raise SystemExit('Missing anchor: '+marker)
  s=s.replace(marker,marker+'\n'+addition,1)
p.write_text(s)
print('M21-E router registration complete')
