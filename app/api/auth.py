"""JSON authentication API for M15-A."""

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import require_current_user
from app.config import settings
from app.database import get_session
from app.models.user import User
from app.schemas.auth import AuthUserResponse, LoginRequest
from app.services.auth_service import (
    authenticate_user,
    clear_session_cookie,
    create_user_session,
    revoke_session,
    set_session_cookie,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/login", response_model=AuthUserResponse)
async def login(
    data: LoginRequest,
    response: Response,
    db: AsyncSession = Depends(get_session),
):
    """Authenticate and issue a persistent server-side session."""
    user = await authenticate_user(db, data.email, data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    _, raw_token = await create_user_session(db, user)
    set_session_cookie(response, raw_token)
    return user


@router.get("/me", response_model=AuthUserResponse)
async def me(current_user: User = Depends(require_current_user)):
    """Return the currently authenticated User."""
    return current_user


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_session),
):
    """Revoke the current session and expire the browser cookie."""
    token = request.cookies.get(settings.AUTH_SESSION_COOKIE_NAME)
    await revoke_session(db, token)
    clear_session_cookie(response)
    return Response(status_code=status.HTTP_204_NO_CONTENT, headers=response.headers)
