import uuid
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
from app.services.game_thank_you_artwork_storage import *
from app.services.game_broadcast_presentation_service import serialize_broadcast_state
from app.sockets import sio,game_room
router=APIRouter(tags=["game-thank-you"])
async def _emit_broadcast_state(db,game_id):
 state=jsonable_encoder(await serialize_broadcast_state(db,game_id));await sio.emit("broadcast:presentation_updated",state,room=game_room(game_id,"overlay"))
async def _manageable(db,user,game_id):
 if user.club_role not in {"DIRECTOR","MANAGER"}:raise HTTPException(403,"Director or Manager access required")
 g=await db.get(Game,game_id)
 if not g or not await can_operate_game(db,user,g):deny_not_found("Game")
 if g.archived_at is not None:raise HTTPException(409,"Archived Games are read-only")
 return g
def state(g):return {"game_id":str(g.id),"enabled":bool(g.thank_you_enabled),"image_url":g.thank_you_image_url,"updated_at":g.thank_you_updated_at}
@router.get("/api/games/{game_id}/thank-you")
async def get_thank_you(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):return state(await _manageable(db,current_user,game_id))
@router.post("/api/games/{game_id}/thank-you/artwork")
async def upload_thank_you(game_id:uuid.UUID,request:Request,artwork:UploadFile=File(...),current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);g=await _manageable(db,current_user,game_id);old=filename_from_url(g.thank_you_image_url)
 try:new=await save_game_thank_you(club_id=g.club_id,game_id=g.id,upload=artwork)
 except GameThankYouTooLargeError as e:raise HTTPException(413,str(e))
 except GameThankYouUnsupportedTypeError as e:raise HTTPException(415,str(e))
 finally:await artwork.close()
 g.thank_you_image_url=f"/api/game-thank-you-assets/{new}";g.thank_you_enabled=True;g.thank_you_updated_at=datetime.now(timezone.utc);await db.commit();await db.refresh(g);delete_filename(old);await _emit_broadcast_state(db,game_id);return state(g)
@router.patch("/api/games/{game_id}/thank-you")
async def patch_thank_you(game_id:uuid.UUID,payload:dict,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);g=await _manageable(db,current_user,game_id);enabled=payload.get("enabled")
 if not isinstance(enabled,bool):raise HTTPException(422,"enabled must be boolean")
 if enabled and not g.thank_you_image_url:raise HTTPException(409,"Upload Thank You Screen artwork first")
 g.thank_you_enabled=enabled;g.thank_you_updated_at=datetime.now(timezone.utc);await db.commit();await db.refresh(g);await _emit_broadcast_state(db,game_id);return state(g)
@router.delete("/api/games/{game_id}/thank-you/artwork",status_code=204)
async def remove_thank_you(game_id:uuid.UUID,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);g=await _manageable(db,current_user,game_id);old=filename_from_url(g.thank_you_image_url);g.thank_you_image_url=None;g.thank_you_enabled=False;g.thank_you_updated_at=datetime.now(timezone.utc);await db.commit();delete_filename(old);await _emit_broadcast_state(db,game_id);return Response(status_code=204)
@router.get("/api/game-thank-you-assets/{filename}")
async def asset(filename:str):
 try:p=path_for_filename(filename)
 except FileNotFoundError:raise HTTPException(404,"Game Thank You asset not found")
 return FileResponse(p,headers={"Cache-Control":"public, max-age=31536000, immutable"})
