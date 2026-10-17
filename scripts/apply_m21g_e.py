#!/usr/bin/env python3
"""M21-G-E additive, idempotent Futsal broadcast refinement installer."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
template = root / 'templates/sports/futsal_overlay.html'
css = root / 'static/css/futsal-overlay-m21ge.css'
js = root / 'static/js/sports/futsal_overlay_m21ge.js'

if not all(p.is_file() for p in (template, css, js)):
    raise SystemExit('ERROR: Required files missing. Unzip archive at repository root.')
html = template.read_text()
if 'futsal-overlay-m21d.css' not in html or 'futsal_overlay_m21d.js' not in html:
    raise SystemExit('ERROR: Expected M21-D overlay template not found. No changes made.')
css_link = '<link rel="stylesheet" href="/static/css/futsal-overlay-m21ge.css?v=m21ge1">'
js_tag = '<script src="/static/js/sports/futsal_overlay_m21ge.js?v=m21ge1" defer></script>'
updated = html
if css_link not in updated:
    updated = updated.replace('</head>', css_link + '</head>', 1)
if js_tag not in updated:
    updated = updated.replace('</body>', js_tag + '</body>', 1)
if updated != html:
    shutil.copy2(template, template.with_suffix('.html.m21ge-backup'))
    template.write_text(updated)
    print('PASS: Futsal overlay assets linked; template backup created.')
else:
    print('PASS: M21-G-E assets already linked; no changes required.')
print('PASS: Soccer assets, APIs and database migrations untouched.')
