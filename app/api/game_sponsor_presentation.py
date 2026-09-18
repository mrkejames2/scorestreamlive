"""M19-E authenticated live sponsor presentation controls."""
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
from app.schemas.game_sponsor_presentation import SponsorPresentationUpdate
from app.services.game_sponsor_presentation_service import serialize_presentation,update_presentation
from app.sockets import sio
router=APIRouter(prefix="/api/games",tags=["sponsor-presentation"]); logger=logging.getLogger("app")
async def _require_operator(db,user,game_id):
    g=await db.get(Game,game_id)
    if not g or not await can_operate_game(db,user,g): deny_not_found("Game")
    return g
@router.get("/{game_id}/sponsor-presentation")
async def get_state(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    await _require_operator(db,current_user,game_id); return jsonable_encoder(await serialize_presentation(db,game_id))
@router.patch("/{game_id}/sponsor-presentation")
async def patch_state(game_id:uuid.UUID,data:SponsorPresentationUpdate,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    require_same_origin_mutation(request); await _require_operator(db,current_user,game_id); state=await update_presentation(db,game_id,data); payload=jsonable_encoder(state)
    try: await sio.emit("sponsor:presentation_updated",payload)
    except Exception: logger.exception("Failed to emit sponsor presentation update",extra={"game_id":str(game_id)})
    return payload
