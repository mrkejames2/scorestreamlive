#!/usr/bin/env python3
"""M21-G-D guarded, repeatable Control Center UI refinement."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def patch(rel,changes):
 p=ROOT/rel
 if not p.is_file(): raise SystemExit(f'Missing prerequisite: {rel}')
 s=p.read_text()
 for old,new in changes:
  if new in s: continue
  if old not in s: raise SystemExit(f'Unexpected baseline in {rel}: {old[:90]!r}')
  s=s.replace(old,new,1)
 p.write_text(s)
 print('OK',rel)

patch('templates/sports/futsal_controls.html',[
 ('<link rel="stylesheet" href="/static/css/account-nav.css">','<link rel="stylesheet" href="/static/css/account-nav.css">'),
 ('<style id="m21f-r4-hide">','<link rel="stylesheet" href="/static/css/futsal-control-m21gd.css?v=m21gd1"><style id="m21f-r4-hide">'),
 ('<div class="brand">ScoreStreamLive</div>','<a class="brand m21gd-brand" href="/sports/home">SCORE<span>STREAM</span>LIVE</a>'),
 ('<a href="/futsal/games#futsal-rosters">Teams &amp; Rosters</a>','<a href="/futsal/teams">Teams &amp; Rosters</a>'),
 ('<a href="/futsal/games#futsal-rosters">Teams &amp; Rosters</a>','<a href="/futsal/teams">Teams &amp; Rosters</a>'),
 ('<a href="/futsal/overlay/games/{{ game_id }}"','<a href="/futsal/games/{{ game_id }}/overlay"'),
 ('<a href="/futsal/overlay/games/{{ game_id }}"','<a href="/futsal/games/{{ game_id }}/overlay"'),
 ('<div class="status" id="connection-state">CONNECTING</div>','<div class="status" id="connection-state" role="status" aria-live="polite">CONNECTING</div>'),
 ('<div class="actions"><button data-clock="start"','<div class="actions" aria-label="Match clock actions"><button data-clock="start"'),
 ('<p id="notice" role="status" aria-live="polite"></p>','<p id="notice" role="status" aria-live="polite"></p>'),
 ('</body></html>','<script src="/static/js/sports/futsal_control_m21gd.js?v=m21gd1" defer></script></body></html>')
])
patch('static/js/sports/futsal_roster_m21f_r4.js',[
 ('link.href=`/teams/${encodeURIComponent(id)}`','link.href=`/futsal/teams/${encodeURIComponent(id)}?return_to=${encodeURIComponent(`/futsal/games/${gameId}/control`)}`')
])
css='''/* M21-G-D: align Futsal Control Center with M21-G-B R2, without touching clock/scoring logic. */
:root{--navy:#13243a;--ink:#1b3040;--blue:#225eaf}
body{background:#f7f9fc}
.sidebar{background:#13243a;width:248px;padding:27px 17px;position:sticky;top:0;height:100vh}
.m21gd-brand{display:block;color:#ff6b0b;text-decoration:none;font-size:15px;font-weight:950;letter-spacing:.065em;white-space:nowrap}
.m21gd-brand span{color:#f2f7ff}
.brand-sub{color:#96aec9;font-weight:800;letter-spacing:.13em;margin-top:20px;margin-bottom:24px}
.sidebar nav{gap:7px}.sidebar nav a{border-radius:10px;color:#cbdaf0;font-size:14px;font-weight:800;padding:12px 14px}
.sidebar nav a[href$="/control"]{background:#225eaf;color:#fff}
.sidebar nav a:hover,.sidebar nav a:focus-visible{background:#263e5d;color:#fff}
.main{max-width:1320px}.card{border-color:#d5e0eb;box-shadow:0 3px 14px #13243a0c}
.status-strip>div{border-color:#d5e0eb}.status-strip span,.section-heading>span{color:#536a82}
.scoreboard .team{display:flex;flex-direction:column;align-items:center;gap:7px}
.scoreboard .team button{width:100%;max-width:300px}
.scoreboard .team .roster-link{font-weight:750;color:#175fa5}
.actions button{flex:1 1 125px}.actions button:disabled{opacity:.45}
#notice:not(:empty){padding:12px 15px;background:#fff8e9;border:1px solid #f1d9a9;border-radius:9px}
.m21gd-return{display:inline-flex;align-items:center;min-height:44px;color:#155b9b;font-weight:800;text-decoration:none}
.m21gd-return:hover{text-decoration:underline}
.m21gd-help{font-size:.88rem;color:#4c647c;margin:0 0 12px}
@media(max-width:650px){.sidebar{display:none}.main{padding:16px 12px}.page-header h1{font-size:2rem}.mobile-nav{gap:7px}.mobile-nav a{border:1px solid #cbd9e7}.scoreboard .team{min-width:0}.scoreboard .team button{padding:12px 7px}.scoreboard .team-name{font-size:1rem}.status-strip{grid-template-columns:1fr}}
'''
js='''/* M21-G-D: presentation-only enhancements. Existing M21-F scripts own state and mutations. */
(()=>{'use strict';
const id=document.body.dataset.gameId;if(!id)return;
const main=document.querySelector('.main');const header=document.querySelector('.page-header');
if(header){const a=document.createElement('a');a.className='m21gd-return';a.href='/futsal/games';a.textContent='← Back to Futsal Games';header.insertAdjacentElement('beforebegin',a)}
for(const nav of document.querySelectorAll('.sidebar nav,.mobile-nav')){
 const links=[...nav.querySelectorAll('a')];for(const a of links){if(a.getAttribute('href')==='/futsal/games#futsal-rosters')a.href='/futsal/teams';if(a.getAttribute('href')===`/futsal/overlay/games/${id}`)a.href=`/futsal/games/${encodeURIComponent(id)}/overlay`;}
 const games=nav.querySelector('a[href="/futsal/games"]');if(games){games.setAttribute('aria-label','Return to Futsal Games')}
}
const clockSection=[...document.querySelectorAll('.card')].find(c=>c.querySelector('[data-clock]'));
if(clockSection){const hint=document.createElement('p');hint.className='m21gd-help';hint.textContent='Clock controls use the saved match state. Start, pause, resume, and advance halves here; use Clock Setup to configure the match duration.';const actions=clockSection.querySelector('.actions');actions?.insertAdjacentElement('beforebegin',hint)}
const conn=document.getElementById('connection-state');const label=document.getElementById('connection-label');
if(conn&&label){const observer=new MutationObserver(()=>{const status=document.getElementById('notice')?.textContent||'';const failed=/failed|unavailable|error/i.test(status);conn.textContent=failed?'CHECK STATUS':'CONTROL READY';label.textContent=failed?'CHECK STATUS':'ACTIVE';});observer.observe(document.getElementById('notice'),{childList:true,characterData:true,subtree:true});conn.textContent='CONTROL READY';label.textContent='ACTIVE';}
})();
'''
for rel,data in [('static/css/futsal-control-m21gd.css',css),('static/js/sports/futsal_control_m21gd.js',js)]:
 p=ROOT/rel;p.parent.mkdir(parents=True,exist_ok=True)
 if p.exists() and p.read_text()!=data:raise SystemExit(f'Existing different file: {rel}')
 p.write_text(data);print('OK',rel)
print('M21-G-D installed; no database migrations or backend behavior changed.')
