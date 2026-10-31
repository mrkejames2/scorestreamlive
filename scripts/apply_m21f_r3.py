#!/usr/bin/env python3
# M21-F R3 fail-closed installer
from pathlib import Path
import ast
import sys
root=Path.cwd()
required=['app/models/scoring_event.py','app/schemas/scoring_event.py','app/services/scoring_service.py','static/js/sports/futsal_controls_m21e.js','templates/sports/futsal_controls.html','templates/sports/futsal_games.html','static/css/futsal-control-m21f-r2.css','alembic/versions/20261016_0041_m21c_futsal_clock.py']
for f in required:
    if not (root/f).is_file():sys.exit(f'Missing {f}; install M21-F R2 first.')
changes={}
def edit(path,old,new):
    content=changes.get(path,(root/path).read_text())
    if new in content:return
    if old not in content:sys.exit(f'Unexpected {path}: expected anchor missing. No files written.')
    changes[path]=content.replace(old,new,1)

edit('app/models/scoring_event.py',
'''    game_elapsed_seconds: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
    )''',
'''    game_elapsed_seconds: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
    )

    # M21-F R3: immutable countdown snapshot at goal creation (futsal only).
    futsal_period: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    futsal_remaining_seconds: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)''')
edit('app/schemas/scoring_event.py',
'''    game_elapsed_seconds: Optional[int] = None''',
'''    game_elapsed_seconds: Optional[int] = None
    futsal_period: Optional[int] = None
    futsal_remaining_seconds: Optional[int] = None''')
edit('app/services/scoring_service.py',
'''from app.models.game_clock import GameClock''',
'''from app.models.game_clock import GameClock
from app.models.futsal_clock_config import FutsalClockConfig''')
edit('app/services/scoring_service.py',
'''        "game_elapsed_seconds": event.game_elapsed_seconds,''',
'''        "game_elapsed_seconds": event.game_elapsed_seconds,
        "futsal_period": event.futsal_period,
        "futsal_remaining_seconds": event.futsal_remaining_seconds,''')
edit('app/services/scoring_service.py',
'''    # 6. Create ScoringEvent. request_id is caller-generated''',
'''    # M21-F R3: snapshot the Futsal half and countdown *in this transaction*.
    # The shared clock remains authoritative. Never derive the half later from
    # mutable FutsalClockConfig.updated_at.
    futsal_period = None
    futsal_remaining_seconds = None
    if game.sport == "futsal":
        cfg = await db.get(FutsalClockConfig, data.game_id)
        if cfg is not None and game_elapsed_seconds is not None:
            futsal_period = int(cfg.period)
            futsal_remaining_seconds = max(0, int(cfg.period_seconds) - game_elapsed_seconds)

    # 6. Create ScoringEvent. request_id is caller-generated''')
edit('app/services/scoring_service.py',
'''        game_elapsed_seconds=game_elapsed_seconds,
        created_at=now,''',
'''        game_elapsed_seconds=game_elapsed_seconds,
        futsal_period=futsal_period,
        futsal_remaining_seconds=futsal_remaining_seconds,
        created_at=now,''')
# The original JS has no whitespace after event_type: use exact alternate if needed.
js_path='static/js/sports/futsal_controls_m21e.js'
js=changes.get(js_path,(root/js_path).read_text())
if "player_id:(document.getElementById" not in js:
    if 'player_id:null,event_type:' not in js:sys.exit('Unexpected goal command JS; no files written')
    changes[js_path]=js.replace('player_id:null,event_type:', 'player_id:(document.getElementById(`${b.dataset.goal}-scorer`)?.value||null),event_type:',1)
# Insert roster selectors in the existing responsive R2 UI, not a separate control panel.
t='templates/sports/futsal_controls.html'
for side in ('home','away'):
    edit(t,f'<button data-goal="{side}" class="primary">',
    f'<div class="scorer-picker"><label for="{side}-scorer">Goal scorer</label><select id="{side}-scorer" aria-label="{side.title()} goal scorer"><option value="">Team goal / unknown scorer</option></select></div><a class="roster-link" id="{side}-roster-link" href="/futsal/games#futsal-rosters">Manage {side.title()} Roster</a><button data-goal="{side}" class="primary">')
edit(t,'<section class="card"><div class="section-heading"><h2>Match Clock',
'<p class="roster-note" id="roster-notice" role="status" aria-live="polite">Loading team rosters…</p><section class="card"><div class="section-heading"><h2>Match Clock')
edit(t,'<a href="/futsal/games">Games</a>',
'<a href="/futsal/games">Games</a><a href="/futsal/games#futsal-rosters">Teams &amp; Rosters</a>')
edit(t,'<a href="/futsal/games">Games</a><a href="/futsal/games/{{ game_id }}/clock">',
'<a href="/futsal/games">Games</a><a href="/futsal/games#futsal-rosters">Teams &amp; Rosters</a><a href="/futsal/games/{{ game_id }}/clock">')
edit(t,'<link rel="stylesheet" href="/static/css/futsal-control-m21f-r2.css?v=m21fr2">',
'<link rel="stylesheet" href="/static/css/futsal-control-m21f-r2.css?v=m21fr2"><link rel="stylesheet" href="/static/css/futsal-control-m21f-r3.css?v=m21fr3">')
edit(t,'<script src="/static/js/sports/futsal_corrections_m21f.js?v=m21fr2" defer></script>',
'<script src="/static/js/sports/futsal_roster_m21f_r3.js?v=m21fr3" defer></script><script src="/static/js/sports/futsal_corrections_m21f.js?v=m21fr3" defer></script>')
edit(t,'<script src="/static/js/sports/futsal_controls_m21e.js?v=m21fr2" defer></script>',
'<script src="/static/js/sports/futsal_controls_m21e.js?v=m21fr3" defer></script>')
# Replace obsolete Soccer correction links from older template, if present.
s=changes.get(t,(root/t).read_text())
s=s.replace('Goals use the existing scoring-event service and can be corrected in the main Control Center.', 'Goals use the shared scoring-event service; correct them below.')
s=s.replace('<p><a href="/control/games/{{ game_id }}">Open full Control Center for scoring corrections and match lifecycle</a></p>','')
changes[t]=s
# Futsal Games: roster management links to existing team detail editor.
g='templates/sports/futsal_games.html'
edit(g,'<a href="/teams">Soccer Teams</a>', '<a href="#futsal-rosters">Teams &amp; Rosters</a>')
edit(g,'<h2>Futsal Games</h2><section id="games"></section>',
'<h2 id="futsal-rosters">Futsal Teams &amp; Rosters</h2><p>Select a team to manage players using the shared ScoreStreamLive roster editor.</p><section id="futsal-team-rosters"></section><h2>Futsal Games</h2><section id="games"></section>')
edit(g,"el('games').replaceChildren();for(const g of games)",
"el('futsal-team-rosters').replaceChildren();for(const t of teams){const a=document.createElement('a'),row=document.createElement('article');a.href='/teams/'+encodeURIComponent(t.id);a.textContent=t.name+' — Manage Roster';row.append(a);el('futsal-team-rosters').append(row)}el('games').replaceChildren();for(const g of games)")
edit(g,"a.href='/games/'+g.id", "a.href='/futsal/games/'+g.id+'/control'")
# Verify python edits before changing anything on disk.
for path,content in changes.items():
    if path.endswith('.py'):ast.parse(content,filename=path)
for path,content in changes.items():
    (root/path).write_text(content)
    print('Updated',path)
print('M21-F R3 integration complete. Apply Alembic revision 20261016_0042 before testing goals.')
