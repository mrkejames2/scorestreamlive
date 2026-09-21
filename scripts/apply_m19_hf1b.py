#!/usr/bin/env python3
from pathlib import Path
ROOT=Path.cwd()
def read(p):return (ROOT/p).read_text()
def write(p,s):(ROOT/p).write_text(s)
def repl(p,old,new):
 s=read(p)
 if new in s: print('PASS already integrated:',p);return
 if s.count(old)!=1:raise SystemExit(f'FAIL {p}: expected one integration anchor, found {s.count(old)}')
 write(p,s.replace(old,new));print('PASS integrated:',p)

repl('app/models/game.py','    intro_updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)\n','    intro_updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)\n    thank_you_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)\n    thank_you_enabled: Mapped[bool] = mapped_column(nullable=False, default=False)\n    thank_you_updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)\n')
repl('app/models/game_broadcast_presentation.py','    __table_args__=(CheckConstraint("scene IN (\'intro\',\'live\')",name="ck_game_broadcast_presentations_scene"),)\n','    __table_args__=(CheckConstraint("scene IN (\'intro\',\'live\',\'summary\',\'thank_you\')",name="ck_game_broadcast_presentations_scene"),)\n')

service='''from datetime import datetime,timezone
from fastapi import HTTPException
from app.models.game import Game
from app.models.game_broadcast_presentation import GameBroadcastPresentation
VALID_SCENES={"intro","live","summary","thank_you"}
def _now():return datetime.now(timezone.utc)
async def serialize_broadcast_state(db,game_id):
 game=await db.get(Game,game_id)
 if not game:raise HTTPException(404,"Game not found")
 row=await db.get(GameBroadcastPresentation,game_id);intro_available=bool(game.intro_enabled and game.intro_image_url);thank_available=bool(game.thank_you_enabled and game.thank_you_image_url);scene=row.scene if row else ("intro" if intro_available else "live")
 if scene=="intro" and not intro_available:scene="live"
 if scene=="thank_you" and not thank_available:scene="live"
 return {"game_id":str(game.id),"scene":scene,"version":row.version if row else 0,"updated_at":row.updated_at if row else (game.intro_updated_at or game.thank_you_updated_at),"intro":{"enabled":bool(game.intro_enabled),"image_url":game.intro_image_url if intro_available else None},"thank_you":{"enabled":bool(game.thank_you_enabled),"image_url":game.thank_you_image_url if thank_available else None}}
async def update_broadcast_scene(db,game_id,scene,expected_version):
 game=await db.get(Game,game_id)
 if not game:raise HTTPException(404,"Game not found")
 if game.archived_at is not None:raise HTTPException(409,"Archived Games are read-only")
 if scene not in VALID_SCENES:raise HTTPException(422,"Unsupported broadcast scene")
 if scene=="intro" and not(game.intro_enabled and game.intro_image_url):raise HTTPException(409,"Welcome Screen is not available")
 if scene=="thank_you" and not(game.thank_you_enabled and game.thank_you_image_url):raise HTTPException(409,"Thank You Screen is not available")
 row=await db.get(GameBroadcastPresentation,game_id);now=_now()
 if row is None:
  if expected_version not in (None,0):raise HTTPException(409,"Broadcast presentation changed; refetch current state")
  row=GameBroadcastPresentation(game_id=game_id,scene=scene,version=1,created_at=now,updated_at=now);db.add(row)
 else:
  if expected_version is not None and row.version!=expected_version:raise HTTPException(409,"Broadcast presentation changed; refetch current state")
  row.scene=scene;row.version+=1;row.updated_at=now
 await db.commit();await db.refresh(row);return await serialize_broadcast_state(db,game_id)
'''
p='app/services/game_broadcast_presentation_service.py';s=read(p)
if 'VALID_SCENES={"intro","live","summary","thank_you"}' not in s:
 if 'scene not in {"intro","live"}' not in s:raise SystemExit('FAIL broadcast service: M19-H anchor missing')
 write(p,service);print('PASS integrated:',p)

repl('app/main.py','from app.api.game_intro import router as game_intro_router\n','from app.api.game_intro import router as game_intro_router\nfrom app.api.game_thank_you import router as game_thank_you_router\n')
repl('app/main.py','app.include_router(game_intro_router)\n','app.include_router(game_intro_router)\napp.include_router(game_thank_you_router)\n')

p='templates/stream/game.html';s=read(p)
old='''  <main id="broadcast-root">
    <div id="intro-scene" class="scene hidden">
      <img id="intro-image" alt="Game welcome screen">
    </div>
    <iframe
      id="live-scene"
      class="scene"
      title="ScoreStreamLive live game"
      src="/overlay/games/{{ game_id }}">
    </iframe>
  </main>
'''
new='''  <main id="broadcast-root">
    <div id="intro-scene" class="scene hidden"><img id="intro-image" alt="Game welcome screen"></div>
    <iframe id="live-scene" class="scene" title="ScoreStreamLive live game" src="/overlay/games/{{ game_id }}"></iframe>
    <iframe id="summary-scene" class="scene hidden" title="ScoreStreamLive game summary" src="/broadcast/games/{{ game_id }}"></iframe>
    <div id="thank-you-scene" class="scene hidden"><img id="thank-you-image" alt="Game thank you screen"></div>
  </main>
'''
if 'id="summary-scene"' not in s:
 if old not in s:raise SystemExit('FAIL stream template: M19-H anchor missing')
 s=s.replace(old,new)
s=s.replace('broadcast-m19h.css?v=m19h-2','broadcast-m19h.css?v=m19hf1b-1').replace('game-m19h.js?v=m19h-2','game-m19h.js?v=m19hf1b-1');write(p,s);print('PASS integrated:',p)

write('static/js/broadcast/game-m19h.js','''const gameId=document.body.dataset.gameId,scenes={intro:document.getElementById("intro-scene"),live:document.getElementById("live-scene"),summary:document.getElementById("summary-scene"),thank_you:document.getElementById("thank-you-scene")},introImg=document.getElementById("intro-image"),thankImg=document.getElementById("thank-you-image");let generation=0;function showScene(name){for(const [n,e] of Object.entries(scenes))e.classList.toggle("hidden",n!==name)}function render(s){const g=++generation;if(s.scene==="intro"&&s.intro?.image_url){introImg.onload=()=>{if(g===generation)showScene("intro")};introImg.onerror=()=>{if(g===generation)showScene("live")};introImg.src=s.intro.image_url;return}if(s.scene==="thank_you"&&s.thank_you?.image_url){thankImg.onload=()=>{if(g===generation)showScene("thank_you")};thankImg.onerror=()=>{if(g===generation)showScene("live")};thankImg.src=s.thank_you.image_url;return}showScene(s.scene==="summary"?"summary":"live")}async function recover(){try{const r=await fetch(`/api/public/games/${gameId}/broadcast-state`,{cache:"no-store"});if(r.ok)render(await r.json())}catch(_){}}await recover();if(window.io){const socket=io({auth:{game_id:gameId,audience:"overlay"}});socket.on("broadcast:presentation_updated",p=>{if(p.game_id===gameId)render(p)});socket.on("connect",recover)}\n''');print('PASS integrated: static/js/broadcast/game-m19h.js')
write('static/css/broadcast-m19h.css','html,body,#broadcast-root{margin:0;width:100%;height:100%;overflow:hidden;background:transparent}#broadcast-root{position:relative}.scene{position:absolute;inset:0;width:100%;height:100%;border:0;opacity:1;transition:opacity .4s ease}.scene.hidden{opacity:0;pointer-events:none}#intro-scene,#thank-you-scene{display:flex;align-items:center;justify-content:center;background:#000}#intro-image,#thank-you-image{width:100%;height:100%;object-fit:contain}\n');print('PASS integrated: static/css/broadcast-m19h.css')

p='templates/control/game.html';s=read(p);old='<article id="m19h-broadcast-controls" class="card operator-card"><div class="card-header"><h2>Broadcast Scene</h2><span id="m19h-scene-state" class="command-status">LOADING</span></div><p class="muted">Switch the stable Broadcast URL between the Welcome Screen and Live Game.</p><div class="m19h-broadcast-actions"><button id="m19h-show-intro" class="secondary-button" type="button">Show Welcome</button><button id="m19h-go-live" class="primary-action" type="button">Go Live</button></div><div id="m19h-broadcast-message" class="m19h-broadcast-message muted" role="status"></div></article>'
new='<article id="m19h-broadcast-controls" class="card operator-card"><div class="card-header"><h2>Broadcast Scene</h2><span id="m19h-scene-state" class="command-status">LOADING</span></div><p class="muted">Control what viewers see on the stable Broadcast URL.</p><div class="m19h-broadcast-actions"><button id="m19h-show-intro" class="secondary-button" type="button">Intro</button><button id="m19h-go-live" class="primary-action" type="button">Live</button><button id="m19hf1b-show-summary" class="secondary-button" type="button">Summary</button><button id="m19hf1b-show-thank-you" class="secondary-button" type="button">Thank You</button></div><div id="m19h-broadcast-message" class="m19h-broadcast-message muted" role="status"></div></article>'
if 'm19hf1b-show-summary' not in s:
 if old not in s:raise SystemExit('FAIL control template: broadcast card anchor missing')
 s=s.replace(old,new)
s=s.replace('control-broadcast-m19h.css?v=m19h-1','control-broadcast-m19h.css?v=m19hf1b-1').replace('broadcast-presentation-m19h.js?v=m19h-1','broadcast-presentation-m19h.js?v=m19hf1b-1');write(p,s);print('PASS integrated:',p)

write('static/js/control/broadcast-presentation-m19h.js','''export async function initBroadcastPresentation(gameId){const root=document.getElementById("m19h-broadcast-controls");if(!root)return;let state=null;const label=document.getElementById("m19h-scene-state"),msg=document.getElementById("m19h-broadcast-message"),intro=document.getElementById("m19h-show-intro"),live=document.getElementById("m19h-go-live"),summary=document.getElementById("m19hf1b-show-summary"),thank=document.getElementById("m19hf1b-show-thank-you");function draw(){label.textContent=(state?.scene||"live").toUpperCase().replace("_"," ");intro.disabled=!state?.intro?.image_url;thank.disabled=!state?.thank_you?.image_url;for(const [n,b] of [["intro",intro],["live",live],["summary",summary],["thank_you",thank]])b.setAttribute("aria-pressed",String(n===(state?.scene||"live")))}async function recover(){const r=await fetch(`/api/games/${gameId}/broadcast-presentation`,{cache:"no-store"});if(r.ok){state=await r.json();draw()}}async function set(scene){const r=await fetch(`/api/games/${gameId}/broadcast-presentation`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({scene,expected_version:state?.version??0})});if(r.ok){state=await r.json();draw();msg.textContent={intro:"Welcome Screen is live.",live:"Live Game scene is active.",summary:"Game Summary is live.",thank_you:"Thank You Screen is live."}[scene]}else{const b=await r.json().catch(()=>({}));msg.textContent=b.detail||"Scene change failed";await recover()}}intro.onclick=()=>set("intro");live.onclick=()=>set("live");summary.onclick=()=>set("summary");thank.onclick=()=>set("thank_you");await recover()}\n''');print('PASS integrated: static/js/control/broadcast-presentation-m19h.js')

p='templates/games/detail.html';s=read(p);anchor='''    <section id="m19h-intro-panel" class="game-intro-panel hidden">
      <div><span class="eyebrow">STREAM WELCOME SCREEN</span><h2>Per-Game Broadcast Intro</h2><p>Recommended 16:9 artwork, 1280×720 or higher.</p></div>
      <div class="game-intro-grid"><img id="m19h-intro-preview" class="game-intro-preview" alt="Welcome Screen preview" hidden><div class="game-intro-actions"><label class="button button-secondary">Upload / Replace Image<input id="m19h-intro-upload" type="file" accept="image/png,image/jpeg,image/webp" hidden></label><label><input id="m19h-intro-enabled" type="checkbox"> Enable Welcome Screen</label><button id="m19h-intro-remove" class="button button-secondary" type="button">Remove Image</button><span id="m19h-intro-message" class="game-intro-message" role="status"></span></div></div>
    </section>
''';panel='''
    <section id="m19hf1b-thank-you-panel" class="game-intro-panel hidden">
      <div><span class="eyebrow">STREAM THANK YOU SCREEN</span><h2>Per-Game Broadcast Closing Screen</h2><p>Recommended 16:9 artwork, 1280×720 or higher.</p></div>
      <div class="game-intro-grid"><img id="m19hf1b-thank-you-preview" class="game-intro-preview" alt="Thank You Screen preview" hidden><div class="game-intro-actions"><label class="button button-secondary">Upload / Replace Image<input id="m19hf1b-thank-you-upload" type="file" accept="image/png,image/jpeg,image/webp" hidden></label><label><input id="m19hf1b-thank-you-enabled" type="checkbox"> Enable Thank You Screen</label><button id="m19hf1b-thank-you-remove" class="button button-secondary" type="button">Remove Image</button><span id="m19hf1b-thank-you-message" class="game-intro-message" role="status"></span></div></div>
    </section>
'''
if 'm19hf1b-thank-you-panel' not in s:
 if anchor not in s:raise SystemExit('FAIL detail template: intro panel anchor missing')
 s=s.replace(anchor,anchor+panel)
intro_script='  <script type="module">import {loadGameIntro} from "/static/js/games/game-intro-m19h.js?v=m19h-1"; loadGameIntro(document.body.dataset.gameId);</script>\n';thank_script='  <script type="module">import {loadGameThankYou} from "/static/js/games/game-thank-you-m19hf1b.js?v=m19hf1b-1"; loadGameThankYou(document.body.dataset.gameId);</script>\n'
if thank_script not in s:
 if intro_script not in s:raise SystemExit('FAIL detail template: intro script anchor missing')
 s=s.replace(intro_script,intro_script+thank_script)
s=s.replace('game-intro-m19h.css?v=m19h-1','game-intro-m19h.css?v=m19hf1b-1');write(p,s);print('PASS integrated:',p)
print('\nM19 HF1B integration complete. STOP and inspect git diff before rebuild/migration.')
