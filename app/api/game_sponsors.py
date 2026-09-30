import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import can_operate_game, deny_not_found
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.game import Game
from app.models.user import User
from app.schemas.game_sponsor import GameSponsorReplace, GameSponsorResponse
from app.services.game_sponsor_service import list_game_sponsors, replace_game_sponsors
router=APIRouter(prefix="/api/games",tags=["game-sponsors"])
async def _manageable_game(db,user,game_id):
    if user.club_id is None: raise HTTPException(status_code=409,detail="User is not assigned to a Club")
    if user.club_role not in {"DIRECTOR","MANAGER"}: raise HTTPException(status_code=403,detail="Director or Manager access required.")
    game=await db.get(Game,game_id)
    if not game or not await can_operate_game(db,user,game): deny_not_found("Game")
    if game.archived_at is not None: raise HTTPException(status_code=409,detail="Archived Games are read-only")
    return game
def _response(rows): return [GameSponsorResponse(sponsor_id=s.id,name=s.name,website_url=s.website_url,artwork_url=s.artwork_url,is_active=s.is_active,starts_at=s.starts_at,ends_at=s.ends_at,display_order=a.display_order) for a,s in rows]
@router.get("/{game_id}/sponsors",response_model=list[GameSponsorResponse])
async def retrieve(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    game=await _manageable_game(db,current_user,game_id)
    return _response(await list_game_sponsors(db,game.club_id,game_id))
@router.put("/{game_id}/sponsors",response_model=list[GameSponsorResponse])
async def replace(game_id:uuid.UUID,data:GameSponsorReplace,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    game=await _manageable_game(db,current_user,game_id)
    return _response(await replace_game_sponsors(db,game.club_id,game_id,data.sponsor_ids))
