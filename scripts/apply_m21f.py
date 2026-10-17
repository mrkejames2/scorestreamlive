#!/usr/bin/env python3
"""M21-F safe root-relative integration installer. Run from repository root."""
from pathlib import Path
import ast
root=Path.cwd()
assert (root/'app/main.py').exists() and (root/'app/api/futsal_clock.py').exists(), 'Run from ScoreStreamLive repo root with M21-E installed'

def patch(path,old,new):
    p=root/path
    content=p.read_text()
    if new in content: print('Already patched:',path);return
    if old not in content: raise SystemExit(f'Expected M21-E anchor missing in {path}; no edit made')
    p.write_text(content.replace(old,new,1));print('Updated:',path)

# Route Futsal away from the Soccer-only lifecycle UI, preserving Soccer behavior.
patch('app/api/control.py',
 'from fastapi.responses import HTMLResponse',
 'from fastapi.responses import HTMLResponse, RedirectResponse')
patch('app/api/control.py',
 '    await require_entitlement(db, game.club_id, BROADCAST_OVERLAY)\n\n    return templates.TemplateResponse(',
 '    await require_entitlement(db, game.club_id, BROADCAST_OVERLAY)\n\n    if game.sport == "futsal":\n        return RedirectResponse(url=f"/futsal/games/{game_id}/control", status_code=303)\n\n    return templates.TemplateResponse(')

# Overlay uses authoritative Futsal period, not optional Soccer lifecycle.
patch('static/js/sports/futsal_overlay_m21d.js',
 "  function periodLabel(snapshot){",
 "  function periodLabel(snapshot, futsalPeriod){\n    if(futsalPeriod===2)return '2ND HALF';\n    if(futsalPeriod===1)return '1ST HALF';")
patch('static/js/sports/futsal_overlay_m21d.js',
 "      el('period').textContent=periodLabel(snapshot);",
 "      let futsalPeriod=null;\n      try {\n        const pr=await fetch(`/api/public/futsal/games/${encodeURIComponent(gameId)}/period`,{cache:'no-store'});\n        if(pr.ok){const pd=await pr.json();futsalPeriod=pd.period;}\n      } catch(e) {console.warn('Futsal period refresh:',e);}\n      el('period').textContent=periodLabel(snapshot,futsalPeriod);")

# Replace Soccer scoring-correction guidance with native Futsal event list.
patch('templates/sports/futsal_controls.html',
 'Goals use the existing scoring-event service and can be corrected in the main Control Center.',
 'Goals are recorded as scoring events. Correct or remove goals below.')
patch('templates/sports/futsal_controls.html',
 '<p id="notice" role="status"></p><p><a href="/control/games/{{ game_id }}">Open full Control Center for scoring corrections and match lifecycle</a></p>',
 '<section><h2>Scoring Events &amp; Corrections</h2><div id="futsal-scoring-events">Loading…</div></section><p id="notice" role="status"></p>')
patch('templates/sports/futsal_controls.html',
 'futsal_controls_m21e.js?v=m21e-1',
 'futsal_controls_m21e.js?v=m21f-1')
patch('templates/sports/futsal_controls.html',
 '</body></html>',
 '<script src="/static/js/sports/futsal_corrections_m21f.js?v=m21f-1" defer></script></body></html>')

# Add sport-aware link for Futsal game list without altering Soccer game list.
p=root/'static/js/sports/futsal_games_m21b.js'
if p.exists():
    s=p.read_text(); print('Futsal game list exists; inspect links manually:',p)

ast.parse((root/'app/api/control.py').read_text())
print('M21-F integration applied. No database migrations.')
