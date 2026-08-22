"""Reusable current-user dependencies for M15-A and future authorization slices."""

from typing import Optional

from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_session
from app.models.user import User
from app.services.auth_service import resolve_session_user


async def get_optional_current_user(
    request: Request,
    db: AsyncSession = Depends(get_session),
) -> Optional[User]:
    """Return the authenticated User or None."""
    token = request.cookies.get(settings.AUTH_SESSION_COOKIE_NAME)
    return await resolve_session_user(db, token)


async def require_current_user(
    current_user: Optional[User] = Depends(get_optional_current_user),
) -> User:
    """Require authentication without making any resource authorization decision."""
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    return current_user
