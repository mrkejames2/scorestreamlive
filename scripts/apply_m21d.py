"""One-time idempotent M21-D integration; run from repository root after extracting ZIP."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
main=root/'app/main.py'
src=main.read_text()
import_line='from app.web.futsal_overlay import router as futsal_overlay_web_router\n'
include_line='app.include_router(futsal_overlay_web_router)\n'
if import_line not in src:
    needle='from app.web.futsal_clock import router as futsal_clock_web_router\n'
    if needle not in src:raise SystemExit('M21-C router not found; aborting without changes')
    src=src.replace(needle,needle+import_line,1)
if include_line not in src:
    needle='app.include_router(futsal_clock_web_router)\n'
    if needle not in src:raise SystemExit('M21-C include_router not found; aborting without changes')
    src=src.replace(needle,needle+include_line,1)
main.write_text(src)
print('M21-D futsal overlay router integrated (idempotent).')
