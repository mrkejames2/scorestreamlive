import logging,uuid
from fastapi import APIRouter,Depends,Request
from fastapi.encoders import jsonable_encoder
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import can_operate_game,deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.game import Game
from app.models.user import User
from app.services.game_broadcast_presentation_service import serialize_broadcast_state,update_broadcast_scene
from app.sockets import sio,game_room
router=APIRouter(tags=["broadcast-presentation"]);logger=logging.getLogger("app")
async def _operator(db,user,game_id):
 g=await db.get(Game,game_id)
 if not g or not await can_operate_game(db,user,g):deny_not_found("Game")
 return g
@router.get("/api/games/{game_id}/broadcast-presentation")
async def get_state(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 await _operator(db,current_user,game_id);return jsonable_encoder(await serialize_broadcast_state(db,game_id))
@router.post("/api/games/{game_id}/broadcast-presentation")
async def set_state(game_id:uuid.UUID,payload:dict,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);await _operator(db,current_user,game_id);state=await update_broadcast_scene(db,game_id,payload.get("scene"),payload.get("expected_version"));out=jsonable_encoder(state)
 try:await sio.emit("broadcast:presentation_updated",out,room=game_room(game_id,"overlay"))
 except Exception:logger.exception("Failed to emit broadcast presentation update",extra={"game_id":str(game_id)})
 return out
