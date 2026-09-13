"""Authenticated effective-entitlement summary for product UX."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.user import User
from app.services.entitlement_service import effective_club_entitlements

router = APIRouter(prefix="/api/account", tags=["entitlements"])

@router.get("/entitlements")
async def account_entitlements(
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    if current_user.club_id is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User is not assigned to a Club")
    return await effective_club_entitlements(db, current_user.club_id)
