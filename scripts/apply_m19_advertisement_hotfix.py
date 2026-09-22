#!/usr/bin/env python3
from pathlib import Path

def replace(path, old, new, count=1):
    p=Path(path); s=p.read_text()
    if old not in s: raise SystemExit(f'STOP: expected text not found in {path}:\n{old[:220]}')
    p.write_text(s.replace(old,new,count)); print(f'PASS: updated {path}')
def write(path, content):
    p=Path(path); p.parent.mkdir(parents=True,exist_ok=True); p.write_text(content); print(f'PASS: wrote {path}')

replace('app/models/game.py','    thank_you_updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)\n','    thank_you_updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)\n    advertisement_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)\n    advertisement_enabled: Mapped[bool] = mapped_column(nullable=False, default=False)\n    advertisement_updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)\n')
replace('app/models/game_broadcast_presentation.py',"CheckConstraint(\"scene IN ('intro','live','summary','thank_you')\",name=\"ck_game_broadcast_presentations_scene\")","CheckConstraint(\"scene IN ('intro','live','advertisement','summary','thank_you')\",name=\"ck_game_broadcast_presentations_scene\")")

write('app/services/game_broadcast_presentation_service.py', '''from datetime import datetime,timezone
from fastapi import HTTPException
from app.models.game import Game
from app.models.game_broadcast_presentation import GameBroadcastPresentation
VALID_SCENES={"intro","live","advertisement","summary","thank_you"}
def _now():return datetime.now(timezone.utc)
def _versioned_asset_url(url,updated_at):
 if not url:return None
 if not updated_at:return url
 separator="&" if "?" in url else "?"
 return f"{url}{separator}v={updated_at.isoformat()}"
async def serialize_broadcast_state(db,game_id):
 game=await db.get(Game,game_id)
 if not game:raise HTTPException(404,"Game not found")
 row=await db.get(GameBroadcastPresentation,game_id);intro_available=bool(game.intro_enabled and game.intro_image_url);advertisement_available=bool(game.advertisement_enabled and game.advertisement_image_url);thank_available=bool(game.thank_you_enabled and game.thank_you_image_url);scene=row.scene if row else ("intro" if intro_available else "live")
 if scene=="intro" and not intro_available:scene="live"
 if scene=="advertisement" and not advertisement_available:scene="live"
 if scene=="thank_you" and not thank_available:scene="live"
 return {"game_id":str(game.id),"scene":scene,"version":row.version if row else 0,"updated_at":row.updated_at if row else (game.intro_updated_at or game.advertisement_updated_at or game.thank_you_updated_at),"intro":{"enabled":bool(game.intro_enabled),"image_url":_versioned_asset_url(game.intro_image_url,game.intro_updated_at) if intro_available else None},"advertisement":{"enabled":bool(game.advertisement_enabled),"image_url":_versioned_asset_url(game.advertisement_image_url,game.advertisement_updated_at) if advertisement_available else None},"thank_you":{"enabled":bool(game.thank_you_enabled),"image_url":_versioned_asset_url(game.thank_you_image_url,game.thank_you_updated_at) if thank_available else None}}
async def update_broadcast_scene(db,game_id,scene,expected_version):
 game=await db.get(Game,game_id)
 if not game:raise HTTPException(404,"Game not found")
 if game.archived_at is not None:raise HTTPException(409,"Archived Games are read-only")
 if scene not in VALID_SCENES:raise HTTPException(422,"Unsupported broadcast scene")
 if scene=="intro" and not(game.intro_enabled and game.intro_image_url):raise HTTPException(409,"Welcome Screen is not available")
 if scene=="advertisement" and not(game.advertisement_enabled and game.advertisement_image_url):raise HTTPException(409,"Advertisement is not available")
 if scene=="thank_you" and not(game.thank_you_enabled and game.thank_you_image_url):raise HTTPException(409,"Thank You Screen is not available")
 row=await db.get(GameBroadcastPresentation,game_id);now=_now()
 if row is None:
  if expected_version not in (None,0):raise HTTPException(409,"Broadcast presentation changed; refetch current state")
  row=GameBroadcastPresentation(game_id=game_id,scene=scene,version=1,created_at=now,updated_at=now);db.add(row)
 else:
  if expected_version is not None and row.version!=expected_version:raise HTTPException(409,"Broadcast presentation changed; refetch current state")
  row.scene=scene;row.version+=1;row.updated_at=now
 await db.commit();await db.refresh(row);return await serialize_broadcast_state(db,game_id)
''')

write('app/services/game_advertisement_artwork_storage.py', '''from __future__ import annotations
import os,uuid
from pathlib import Path
from typing import Optional
from fastapi import UploadFile
from app.config import settings
ALLOWED_CONTENT_TYPES={"image/png","image/jpeg","image/webp"}; EXTENSION_BY_FORMAT={"png":".png","jpeg":".jpg","webp":".webp"}; FILENAME_MARKER="-advertisement-"
class GameAdvertisementStorageError(ValueError): pass
class GameAdvertisementTooLargeError(GameAdvertisementStorageError): pass
class GameAdvertisementUnsupportedTypeError(GameAdvertisementStorageError): pass
def storage_dir()->Path:return Path(settings.GAME_INTRO_STORAGE_DIR).resolve()
def ensure_storage_dir()->Path:
 d=storage_dir();d.mkdir(parents=True,exist_ok=True);return d
def detect_image_format(data:bytes)->Optional[str]:
 if data.startswith(b"\\x89PNG\\r\\n\\x1a\\n"):return "png"
 if len(data)>=3 and data[:3]==b"\\xff\\xd8\\xff":return "jpeg"
 if len(data)>=12 and data[:4]==b"RIFF" and data[8:12]==b"WEBP":return "webp"
 return None
def validate(data,declared):
 if not data:raise GameAdvertisementUnsupportedTypeError("Advertisement artwork file is empty")
 if len(data)>settings.GAME_INTRO_MAX_BYTES:raise GameAdvertisementTooLargeError("Advertisement artwork exceeds the upload limit")
 fmt=detect_image_format(data);expected={"png":"image/png","jpeg":"image/jpeg","webp":"image/webp"}.get(fmt)
 if not fmt or declared not in ALLOWED_CONTENT_TYPES or declared!=expected:raise GameAdvertisementUnsupportedTypeError("Advertisement artwork must be PNG, JPEG, or WebP and match its content type")
 return fmt
async def save_game_advertisement(*,club_id,game_id,upload:UploadFile)->str:
 data=await upload.read(settings.GAME_INTRO_MAX_BYTES+1);fmt=validate(data,upload.content_type);name=f"{club_id}-{game_id}{FILENAME_MARKER}{uuid.uuid4().hex}{EXTENSION_BY_FORMAT[fmt]}";d=ensure_storage_dir();final=d/name;tmp=d/f".{name}.tmp"
 try:tmp.write_bytes(data);os.replace(tmp,final)
 finally:
  if tmp.exists():tmp.unlink(missing_ok=True)
 return name
def path_for_filename(filename):
 if not filename or Path(filename).name!=filename or FILENAME_MARKER not in filename:raise FileNotFoundError(filename)
 p=storage_dir()/filename
 if not p.is_file():raise FileNotFoundError(filename)
 return p
def filename_from_url(url):
 prefix="/api/game-advertisement-assets/"
 if not url or not url.startswith(prefix):return None
 n=url.removeprefix(prefix);return n if Path(n).name==n and FILENAME_MARKER in n else None
def delete_filename(filename):
 if filename and Path(filename).name==filename and FILENAME_MARKER in filename:(storage_dir()/filename).unlink(missing_ok=True)
''')

write('app/api/game_advertisement.py', '''import uuid
from datetime import datetime,timezone
from fastapi import APIRouter,Depends,File,HTTPException,Request,Response,UploadFile
from fastapi.encoders import jsonable_encoder
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import can_operate_game,deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.game import Game
from app.models.user import User
from app.services.game_advertisement_artwork_storage import *
from app.services.game_broadcast_presentation_service import serialize_broadcast_state
from app.sockets import sio,game_room
router=APIRouter(tags=["game-advertisement"])
async def _emit_broadcast_state(db,game_id):
 state=jsonable_encoder(await serialize_broadcast_state(db,game_id));await sio.emit("broadcast:presentation_updated",state,room=game_room(game_id,"overlay"))
async def _manageable(db,user,game_id):
 if user.club_role not in {"DIRECTOR","MANAGER"}:raise HTTPException(403,"Director or Manager access required")
 g=await db.get(Game,game_id)
 if not g or not await can_operate_game(db,user,g):deny_not_found("Game")
 if g.archived_at is not None:raise HTTPException(409,"Archived Games are read-only")
 return g
def state(g):return {"game_id":str(g.id),"enabled":bool(g.advertisement_enabled),"image_url":g.advertisement_image_url,"updated_at":g.advertisement_updated_at}
@router.get("/api/games/{game_id}/advertisement")
async def get_advertisement(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):return state(await _manageable(db,current_user,game_id))
@router.post("/api/games/{game_id}/advertisement/artwork")
async def upload_advertisement(game_id:uuid.UUID,request:Request,artwork:UploadFile=File(...),current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);g=await _manageable(db,current_user,game_id);old=filename_from_url(g.advertisement_image_url)
 try:new=await save_game_advertisement(club_id=g.club_id,game_id=g.id,upload=artwork)
 except GameAdvertisementTooLargeError as e:raise HTTPException(413,str(e))
 except GameAdvertisementUnsupportedTypeError as e:raise HTTPException(415,str(e))
 finally:await artwork.close()
 g.advertisement_image_url=f"/api/game-advertisement-assets/{new}";g.advertisement_enabled=True;g.advertisement_updated_at=datetime.now(timezone.utc);await db.commit();await db.refresh(g);delete_filename(old);await _emit_broadcast_state(db,game_id);return state(g)
@router.patch("/api/games/{game_id}/advertisement")
async def patch_advertisement(game_id:uuid.UUID,payload:dict,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);g=await _manageable(db,current_user,game_id);enabled=payload.get("enabled")
 if not isinstance(enabled,bool):raise HTTPException(422,"enabled must be boolean")
 if enabled and not g.advertisement_image_url:raise HTTPException(409,"Upload Advertisement artwork first")
 g.advertisement_enabled=enabled;g.advertisement_updated_at=datetime.now(timezone.utc);await db.commit();await db.refresh(g);await _emit_broadcast_state(db,game_id);return state(g)
@router.delete("/api/games/{game_id}/advertisement/artwork",status_code=204)
async def remove_advertisement(game_id:uuid.UUID,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);g=await _manageable(db,current_user,game_id);old=filename_from_url(g.advertisement_image_url);g.advertisement_image_url=None;g.advertisement_enabled=False;g.advertisement_updated_at=datetime.now(timezone.utc);await db.commit();delete_filename(old);await _emit_broadcast_state(db,game_id);return Response(status_code=204)
@router.get("/api/game-advertisement-assets/{filename}")
async def asset(filename:str):
 try:p=path_for_filename(filename)
 except FileNotFoundError:raise HTTPException(404,"Game Advertisement asset not found")
 return FileResponse(p,headers={"Cache-Control":"public, max-age=31536000, immutable"})
''')

replace('app/main.py','from app.api.game_thank_you import router as game_thank_you_router\n','from app.api.game_thank_you import router as game_thank_you_router\nfrom app.api.game_advertisement import router as game_advertisement_router\n')
replace('app/main.py','app.include_router(game_thank_you_router)\n','app.include_router(game_thank_you_router)\napp.include_router(game_advertisement_router)\n')

replace('templates/games/detail.html','    <section id="m19hf1b-thank-you-panel" class="game-intro-panel hidden">\n','''    <section id="m19hf2-advertisement-panel" class="game-intro-panel hidden">
      <div><span class="eyebrow">STREAM ADVERTISEMENT</span><h2>Per-Game Broadcast Advertisement</h2><p>Recommended 16:9 artwork, 1280×720 or higher.</p></div>
      <div class="game-intro-grid"><img id="m19hf2-advertisement-preview" class="game-intro-preview" alt="Advertisement preview" hidden><div class="game-intro-actions"><label class="button button-secondary">Upload / Replace Image<input id="m19hf2-advertisement-upload" type="file" accept="image/png,image/jpeg,image/webp" hidden></label><label><input id="m19hf2-advertisement-enabled" type="checkbox"> Enable Advertisement</label><button id="m19hf2-advertisement-remove" class="button button-secondary" type="button">Remove Image</button><span id="m19hf2-advertisement-message" class="game-intro-message" role="status"></span></div></div>
    </section>

    <section id="m19hf1b-thank-you-panel" class="game-intro-panel hidden">
''')
replace('templates/games/detail.html','  <script type="module">import {loadGameThankYou} from "/static/js/games/game-thank-you-m19hf1b.js?v=m19hf1b-1"; loadGameThankYou(document.body.dataset.gameId);</script>\n','  <script type="module">import {loadGameThankYou} from "/static/js/games/game-thank-you-m19hf1b.js?v=m19hf1b-1"; loadGameThankYou(document.body.dataset.gameId);</script>\n  <script type="module">import {loadGameAdvertisement} from "/static/js/games/game-advertisement-m19hf2.js?v=m19hf2-1"; loadGameAdvertisement(document.body.dataset.gameId);</script>\n')
write('static/js/games/game-advertisement-m19hf2.js','''export async function loadGameAdvertisement(gameId){const panel=document.getElementById("m19hf2-advertisement-panel");if(!panel)return;const preview=document.getElementById("m19hf2-advertisement-preview"),enabled=document.getElementById("m19hf2-advertisement-enabled"),msg=document.getElementById("m19hf2-advertisement-message");async function refresh(){const r=await fetch(`/api/games/${gameId}/advertisement`,{cache:"no-store"});if(!r.ok){panel.classList.add("hidden");return}const s=await r.json();panel.classList.remove("hidden");enabled.checked=s.enabled;preview.src=s.image_url?(s.image_url+`${s.image_url.includes("?")?"&":"?"}v=${encodeURIComponent(s.updated_at||"")}`):"";preview.hidden=!s.image_url}document.getElementById("m19hf2-advertisement-upload").onchange=async e=>{const f=e.target.files[0];if(!f)return;const fd=new FormData();fd.append("artwork",f);const r=await fetch(`/api/games/${gameId}/advertisement/artwork`,{method:"POST",body:fd});msg.textContent=r.ok?"Advertisement uploaded.":(await r.json()).detail;e.target.value="";await refresh()};enabled.onchange=async()=>{const r=await fetch(`/api/games/${gameId}/advertisement`,{method:"PATCH",headers:{"Content-Type":"application/json"},body:JSON.stringify({enabled:enabled.checked})});if(!r.ok)msg.textContent=(await r.json()).detail;await refresh()};document.getElementById("m19hf2-advertisement-remove").onclick=async()=>{if(!confirm("Remove this Advertisement?"))return;const r=await fetch(`/api/games/${gameId}/advertisement/artwork`,{method:"DELETE"});msg.textContent=r.ok?"Advertisement removed.":"Unable to remove Advertisement.";await refresh()};await refresh()}
''')

replace('templates/control/game.html','            <button id="m19h-go-live" class="primary-action" type="button">Live</button>\n            <button id="m19hf1b-show-summary" class="secondary-button" type="button">Summary</button>\n','            <button id="m19h-go-live" class="primary-action" type="button">Live</button>\n            <button id="m19hf2-show-advertisement" class="secondary-button" type="button">Advertisement</button>\n            <button id="m19hf1b-show-summary" class="secondary-button" type="button">Summary</button>\n')
replace('templates/control/game.html','broadcast-presentation-m19h.js?v=m19hf1b-2','broadcast-presentation-m19h.js?v=m19hf2-1')
replace('static/js/control/broadcast-presentation-m19h.js','  const live = document.getElementById("m19h-go-live");\n  const summary = document.getElementById("m19hf1b-show-summary");\n','  const live = document.getElementById("m19h-go-live");\n  const advertisement = document.getElementById("m19hf2-show-advertisement");\n  const summary = document.getElementById("m19hf1b-show-summary");\n')
replace('static/js/control/broadcast-presentation-m19h.js','    intro.disabled = !state?.intro?.image_url;\n    thankYou.disabled = !state?.thank_you?.image_url;\n','    intro.disabled = !state?.intro?.image_url;\n    advertisement.disabled = !state?.advertisement?.image_url;\n    thankYou.disabled = !state?.thank_you?.image_url;\n')
replace('static/js/control/broadcast-presentation-m19h.js','      ["live", live],\n      ["summary", summary],\n','      ["live", live],\n      ["advertisement", advertisement],\n      ["summary", summary],\n')
replace('static/js/control/broadcast-presentation-m19h.js','        live: "Live Game scene is active.",\n        summary: "Game Summary is live.",\n','        live: "Live Game scene is active.",\n        advertisement: "Advertisement is live.",\n        summary: "Game Summary is live.",\n')
replace('static/js/control/broadcast-presentation-m19h.js','  live.onclick = () => setScene("live");\n  summary.onclick = () => setScene("summary");\n','  live.onclick = () => setScene("live");\n  advertisement.onclick = () => setScene("advertisement");\n  summary.onclick = () => setScene("summary");\n')

replace('templates/stream/game.html','    <iframe id="live-scene" class="scene" title="ScoreStreamLive live game" src="/overlay/games/{{ game_id }}"></iframe>\n    <iframe id="summary-scene" class="scene hidden" title="ScoreStreamLive game summary" src="/broadcast/games/{{ game_id }}"></iframe>\n','    <iframe id="live-scene" class="scene" title="ScoreStreamLive live game" src="/overlay/games/{{ game_id }}"></iframe>\n    <div id="advertisement-scene" class="scene hidden"><img id="advertisement-image" alt="Game advertisement"></div>\n    <iframe id="summary-scene" class="scene hidden" title="ScoreStreamLive game summary" src="/broadcast/games/{{ game_id }}"></iframe>\n')
replace('templates/stream/game.html','/static/css/broadcast-m19h.css?v=m19hf1b-1','/static/css/broadcast-m19h.css?v=m19hf2-1')
replace('templates/stream/game.html','/static/js/broadcast/game-m19h.js?v=m19hf1b-1','/static/js/broadcast/game-m19h.js?v=m19hf2-1')
write('static/js/broadcast/game-m19h.js','''const gameId=document.body.dataset.gameId,scenes={intro:document.getElementById("intro-scene"),live:document.getElementById("live-scene"),advertisement:document.getElementById("advertisement-scene"),summary:document.getElementById("summary-scene"),thank_you:document.getElementById("thank-you-scene")},introImg=document.getElementById("intro-image"),advertisementImg=document.getElementById("advertisement-image"),thankImg=document.getElementById("thank-you-image");let generation=0;function showScene(name){for(const [n,e] of Object.entries(scenes))e.classList.toggle("hidden",n!==name)}function render(s){const g=++generation;if(s.scene==="intro"&&s.intro?.image_url){introImg.onload=()=>{if(g===generation)showScene("intro")};introImg.onerror=()=>{if(g===generation)showScene("live")};introImg.src=s.intro.image_url;return}if(s.scene==="advertisement"&&s.advertisement?.image_url){advertisementImg.onload=()=>{if(g===generation)showScene("advertisement")};advertisementImg.onerror=()=>{if(g===generation)showScene("live")};advertisementImg.src=s.advertisement.image_url;return}if(s.scene==="thank_you"&&s.thank_you?.image_url){thankImg.onload=()=>{if(g===generation)showScene("thank_you")};thankImg.onerror=()=>{if(g===generation)showScene("live")};thankImg.src=s.thank_you.image_url;return}showScene(s.scene==="summary"?"summary":"live")}async function recover(){try{const r=await fetch(`/api/public/games/${gameId}/broadcast-state`,{cache:"no-store"});if(r.ok)render(await r.json())}catch(_){}}await recover();if(window.io){const socket=io({auth:{game_id:gameId,audience:"overlay"}});socket.on("broadcast:presentation_updated",p=>{if(p.game_id===gameId)render(p)});socket.on("connect",recover)}
''')
replace('static/css/broadcast-m19h.css','#intro-scene,#thank-you-scene','#intro-scene,#advertisement-scene,#thank-you-scene')
replace('static/css/broadcast-m19h.css','#intro-image,#thank-you-image','#intro-image,#advertisement-image,#thank-you-image')

write('alembic/versions/20260922_0033_add_broadcast_advertisement_scene.py','''"""M19 hotfix: add per-game Advertisement broadcast scene."""
from alembic import op
import sqlalchemy as sa
revision="20260922_0033"; down_revision="20260921_0032"; branch_labels=None; depends_on=None
CONSTRAINT="ck_game_broadcast_presentations_scene"
def upgrade():
 op.add_column("games",sa.Column("advertisement_image_url",sa.String(500),nullable=True))
 op.add_column("games",sa.Column("advertisement_enabled",sa.Boolean(),nullable=False,server_default=sa.false()))
 op.add_column("games",sa.Column("advertisement_updated_at",sa.DateTime(timezone=True),nullable=True))
 op.drop_constraint(CONSTRAINT,"game_broadcast_presentations",type_="check")
 op.create_check_constraint(CONSTRAINT,"game_broadcast_presentations","scene IN ('intro','live','advertisement','summary','thank_you')")
def downgrade():
 op.execute("UPDATE game_broadcast_presentations SET scene='live' WHERE scene='advertisement'")
 op.drop_constraint(CONSTRAINT,"game_broadcast_presentations",type_="check")
 op.create_check_constraint(CONSTRAINT,"game_broadcast_presentations","scene IN ('intro','live','summary','thank_you')")
 op.drop_column("games","advertisement_updated_at");op.drop_column("games","advertisement_enabled");op.drop_column("games","advertisement_image_url")
''')
print('\nM19 Advertisement hotfix applied successfully. No commit was created.')
