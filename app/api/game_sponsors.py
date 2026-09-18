import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.user import User
from app.schemas.game_sponsor import GameSponsorReplace, GameSponsorResponse
from app.services.game_sponsor_service import list_game_sponsors, replace_game_sponsors
router=APIRouter(prefix="/api/games",tags=["game-sponsors"])
def _director_club(u):
    if u.club_id is None: raise HTTPException(status_code=409,detail="User is not assigned to a Club")
    if u.club_role!="DIRECTOR": raise HTTPException(status_code=403,detail="Director access required.")
    return u.club_id
def _response(rows): return [GameSponsorResponse(sponsor_id=s.id,name=s.name,website_url=s.website_url,artwork_url=s.artwork_url,is_active=s.is_active,starts_at=s.starts_at,ends_at=s.ends_at,display_order=a.display_order) for a,s in rows]
@router.get("/{game_id}/sponsors",response_model=list[GameSponsorResponse])
async def retrieve(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)): return _response(await list_game_sponsors(db,_director_club(current_user),game_id))
@router.put("/{game_id}/sponsors",response_model=list[GameSponsorResponse])
async def replace(game_id:uuid.UUID,data:GameSponsorReplace,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)): return _response(await replace_game_sponsors(db,_director_club(current_user),game_id,data.sponsor_ids))
