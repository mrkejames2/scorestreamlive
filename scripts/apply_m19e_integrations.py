#!/usr/bin/env python3
from pathlib import Path
def rep(path,old,new):
 p=Path(path);t=p.read_text()
 if new in t: print('OK:',path);return
 if old not in t: raise SystemExit('ERROR: M19-D anchor missing: '+path)
 p.write_text(t.replace(old,new,1));print('UPDATED:',path)
rep('app/main.py','from app.api.game_sponsors import router as game_sponsors_router\n','from app.api.game_sponsors import router as game_sponsors_router\nfrom app.api.game_sponsor_presentation import router as game_sponsor_presentation_router\n')
rep('app/main.py','app.include_router(game_sponsors_router)\n','app.include_router(game_sponsors_router)\napp.include_router(game_sponsor_presentation_router)\n')
rep('app/models/__init__.py','from app.models.game_sponsor import GameSponsor\n','from app.models.game_sponsor import GameSponsor\nfrom app.models.game_sponsor_presentation import GameSponsorPresentation\n')
rep('app/models/__init__.py','    "GameSponsor",\n','    "GameSponsor",\n    "GameSponsorPresentation",\n')
rep('app/api/control.py','from app.services.effective_game_sponsor_service import get_effective_game_sponsors\n','from app.services.effective_game_sponsor_service import get_effective_game_sponsors\nfrom app.services.game_sponsor_presentation_service import serialize_presentation\n')
rep('app/api/control.py','        "sponsors": await get_effective_game_sponsors(db, game.id, game.club_id),\n','        "sponsors": await get_effective_game_sponsors(db, game.id, game.club_id),\n        "sponsor_presentation": await serialize_presentation(db, game.id),\n')
rep('templates/control/game.html','  <link rel="stylesheet" href="/static/css/control-m17f.css">\n','  <link rel="stylesheet" href="/static/css/control-m17f.css">\n  <link rel="stylesheet" href="/static/css/control-sponsors-m19e.css?v=m19e-1">\n')
anchor='''      <section class="operator-grid">\n        <article class="card operator-card broadcast-message-card">'''
card='''      <section class="operator-grid">\n        <article id="m19e-sponsor-controls" class="card operator-card sponsor-live-card">\n          <div class="card-header"><h2>Live Sponsor Controls</h2><span id="m19e-zone-state" class="command-status">LOADING</span></div>\n          <p class="muted">Control the Sponsor Zone currently shown on the public broadcast overlay.</p>\n          <div class="sponsor-live-grid"><div class="sponsor-live-current"><span class="muted">Currently Displaying</span><strong id="m19e-current-name">Loading…</strong><img id="m19e-current-artwork" alt="" hidden><span id="m19e-rotation-state" class="sponsor-live-state"></span></div><div class="sponsor-live-settings"><div class="sponsor-live-actions"><button id="m19e-previous" class="secondary-button" type="button">Previous</button><button id="m19e-next" class="secondary-button" type="button">Next</button></div><div class="sponsor-live-actions"><button id="m19e-toggle-rotation" class="secondary-button" type="button">Stop Auto Rotation</button><button id="m19e-toggle-visible" class="secondary-button" type="button">Hide Sponsor Zone</button></div><label>Rotation Interval<select id="m19e-interval"><option value="5">5 seconds</option><option value="10">10 seconds</option><option value="15">15 seconds</option><option value="20">20 seconds</option><option value="30">30 seconds</option><option value="45">45 seconds</option><option value="60">60 seconds</option></select></label><span id="m19e-message" class="muted" role="status"></span></div></div>\n        </article>\n      </section>\n\n'''
rep('templates/control/game.html',anchor,card+anchor)
rep('templates/control/game.html','  <script type="module" src="/static/js/control/m17f-workflow.js"></script>\n','  <script type="module" src="/static/js/control/m17f-workflow.js"></script>\n  <script type="module" src="/static/js/control/sponsors-m19e.js?v=m19e-1"></script>\n')
p=Path('static/js/overlay/overlay.js');t=p.read_text();old='''  sponsors: [],\n  sponsorIndex: 0,''';new='''  sponsors: [],\n  sponsorPresentation: null,\n  sponsorIndex: 0,'''
if new not in t:
 if old not in t: raise SystemExit('ERROR: overlay state anchor missing')
 t=t.replace(old,new,1)
start=t.index('function syncSponsorRotation(){');end=t.index('\n\nfunction applyOverlayTeamBrand',start)
code='''function sponsorBaseIndex(sponsors){const id=String(state.sponsorPresentation?.current_sponsor_id||"");const found=sponsors.findIndex(s=>String(s.id)===id);return found>=0?found:0;}\nfunction syncSponsorRotation(){stopSponsorRotation();const zone=byId("sponsor-zone"),sponsors=usableSponsors(),p=state.sponsorPresentation;if(zone)zone.classList.toggle("hidden",p?.visible===false);if(p?.visible===false)return;if(!sponsors.length){showSponsorFallback();return;}const base=sponsorBaseIndex(sponsors),interval=Math.max(5,Number(p?.rotation_interval_seconds||10))*1000;let index=base;if(p?.rotation_enabled!==false&&p?.updated_at){const anchor=Date.parse(p.updated_at);if(Number.isFinite(anchor))index=(base+Math.max(0,Math.floor((Date.now()-anchor)/interval)))%sponsors.length;}displaySponsorAt(index,false);if(p?.rotation_enabled!==false&&sponsors.length>1)state.sponsorRotationTimer=window.setTimeout(()=>syncSponsorRotation(),interval);}\n'''
t=t[:start]+code+t[end:]
old='''  state.sponsors = snapshot.sponsors || [];\n  state.sponsorIndex = 0;\n  syncSponsorRotation();''';new='''  state.sponsors = snapshot.sponsors || [];\n  state.sponsorPresentation = snapshot.sponsor_presentation || null;\n  state.sponsorIndex = 0;\n  syncSponsorRotation();'''
if new not in t:
 if old not in t: raise SystemExit('ERROR: overlay snapshot anchor missing')
 t=t.replace(old,new,1)
old='''  socket.on("game:updated", recoverIfThisGame);\n  socket.on("game:score_updated", recoverIfThisGame);''';new='''  socket.on("game:updated", recoverIfThisGame);\n  socket.on("game:score_updated", recoverIfThisGame);\n  socket.on("sponsor:presentation_updated", (payload) => { if (!belongsToThisGame(payload)) return; state.sponsors=payload.sponsors||[]; state.sponsorPresentation=payload; syncSponsorRotation(); });'''
if new not in t:
 if old not in t: raise SystemExit('ERROR: overlay socket anchor missing')
 t=t.replace(old,new,1)
p.write_text(t);print('UPDATED: static/js/overlay/overlay.js')
rep('templates/overlay/game.html','<script type="module" src="/static/js/overlay/overlay.js?v=m19d-1"></script>','<script type="module" src="/static/js/overlay/overlay.js?v=m19e-1"></script>')
print('M19-E integrations applied.')
