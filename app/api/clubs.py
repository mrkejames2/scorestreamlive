"""Authenticated Club context API for M15-B."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.user import User
from app.schemas.club import ClubResponse
from app.services.club_service import get_club

router = APIRouter(prefix="/api/clubs", tags=["clubs"])

@router.get("/current", response_model=ClubResponse)
async def current_club(current_user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    if current_user.club_id is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User is not assigned to a Club")
    club = await get_club(db, current_user.club_id)
    if not club:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User Club assignment is invalid")
    return club
