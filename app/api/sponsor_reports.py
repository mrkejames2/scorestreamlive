"""M19-G per-game sponsor appearance reporting."""
import uuid
from fastapi import APIRouter,Depends
from fastapi.encoders import jsonable_encoder
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import can_view_game,deny_not_found
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.game import Game
from app.models.user import User
from app.services.sponsor_impression_service import sponsor_report
router=APIRouter(prefix="/api/games",tags=["sponsor-report"])
@router.get("/{game_id}/sponsor-report")
async def get_sponsor_report(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    game=await db.get(Game,game_id)
    if not game or not await can_view_game(db,current_user,game):deny_not_found("Game")
    return jsonable_encoder(await sponsor_report(db,game_id))
