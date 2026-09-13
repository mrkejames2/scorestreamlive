"""HTTP adapter for provider-neutral Club entitlement enforcement."""
import uuid
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.services.entitlement_service import require_effective_club_entitlement

async def require_entitlement(db: AsyncSession, club_id: uuid.UUID, entitlement_code: str) -> None:
    try:
        await require_effective_club_entitlement(db, club_id, entitlement_code)
    except PermissionError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your current plan does not include this feature.",
        ) from exc
