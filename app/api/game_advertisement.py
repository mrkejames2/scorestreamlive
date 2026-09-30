import uuid
from datetime import datetime,timezone
from fastapi import APIRouter,Depends,HTTPException,Request,Response
from fastapi.encoders import jsonable_encoder
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import can_operate_game,deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.broadcast_artwork import BroadcastArtwork
from app.models.game import Game
from app.models.user import User
from app.services.game_advertisement_artwork_storage import path_for_filename
from app.services.game_broadcast_presentation_service import serialize_broadcast_state
from app.sockets import sio,game_room
router=APIRouter(tags=["game-advertisement"])
async def emit(db,gid):await sio.emit("broadcast:presentation_updated",jsonable_encoder(await serialize_broadcast_state(db,gid)),room=game_room(gid,"overlay"))
async def manageable(db,u,gid):
 if u.club_role not in {"DIRECTOR","MANAGER"}:raise HTTPException(403,"Director or Manager access required")
 g=await db.get(Game,gid)
 if not g or not await can_operate_game(db,u,g):deny_not_found("Game")
 if g.archived_at is not None:raise HTTPException(409,"Archived Games are read-only")
 return g
def state(g):return {"game_id":str(g.id),"enabled":bool(g.advertisement_enabled),"image_url":g.advertisement_image_url,"artwork_id":str(g.advertisement_artwork_id) if g.advertisement_artwork_id else None,"updated_at":g.advertisement_updated_at}
@router.get("/api/games/{game_id}/advertisement")
async def get(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):return state(await manageable(db,current_user,game_id))
@router.put("/api/games/{game_id}/advertisement/artwork-selection")
async def select_art(game_id:uuid.UUID,payload:dict,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);g=await manageable(db,current_user,game_id)
 try:aid=uuid.UUID(str(payload.get("artwork_id")))
 except Exception:raise HTTPException(422,"Valid artwork_id required")
 a=await db.get(BroadcastArtwork,aid)
 if not a or a.club_id!=g.club_id:raise HTTPException(404,"Broadcast artwork not found")
 g.advertisement_artwork_id=a.id;g.advertisement_image_url=a.image_url;g.advertisement_enabled=True;g.advertisement_updated_at=datetime.now(timezone.utc);await db.commit();await db.refresh(g);await emit(db,game_id);return state(g)
@router.patch("/api/games/{game_id}/advertisement")
async def toggle(game_id:uuid.UUID,payload:dict,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);g=await manageable(db,current_user,game_id);v=payload.get("enabled")
 if not isinstance(v,bool):raise HTTPException(422,"enabled must be boolean")
 if v and not g.advertisement_image_url:raise HTTPException(409,"Select Advertisement artwork first")
 g.advertisement_enabled=v;g.advertisement_updated_at=datetime.now(timezone.utc);await db.commit();await db.refresh(g);await emit(db,game_id);return state(g)
@router.delete("/api/games/{game_id}/advertisement/artwork",status_code=204)
async def clear(game_id:uuid.UUID,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);g=await manageable(db,current_user,game_id);g.advertisement_artwork_id=None;g.advertisement_image_url=None;g.advertisement_enabled=False;g.advertisement_updated_at=datetime.now(timezone.utc);await db.commit();await emit(db,game_id);return Response(status_code=204)
@router.get("/api/game-advertisement-assets/{filename}")
async def legacy_asset(filename:str):
 try:p=path_for_filename(filename)
 except FileNotFoundError:raise HTTPException(404,"Game Advertisement asset not found")
 return FileResponse(p,headers={"Cache-Control":"public, max-age=31536000, immutable"})
