"""Club-scoped Game REST API routes."""

import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import can_operate_game, deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.roles import ClubRole
from app.database import get_session
from app.models.user import User
from app.schemas.game import GameBroadcastMessageUpdate, GameCreate, GameUpdate, GameResponse
from app.services.game_service import create_game, list_games, get_game, update_broadcast_message, update_game

router = APIRouter(prefix="/api/games", tags=["games"])


def _require_club(user: User) -> uuid.UUID:
    if user.club_id is None:
        raise HTTPException(status_code=409, detail="User is not assigned to a Club")
    return user.club_id


@router.post("", response_model=GameResponse, status_code=status.HTTP_201_CREATED)
async def create(
    data: GameCreate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Create a Game inside the authenticated User's Club."""
    club_id = _require_club(current_user)
    if current_user.club_role not in {ClubRole.DIRECTOR.value, ClubRole.MANAGER.value}:
        raise HTTPException(status_code=403, detail="Insufficient permission")
    try:
        return await create_game(db, data, club_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))


@router.get("", response_model=list[GameResponse])
async def list_all(
    limit: Optional[int] = Query(default=None, ge=1, le=100),
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """List Games only from the authenticated User's Club."""
    return await list_games(db, limit=limit, club_id=_require_club(current_user))


@router.get("/{game_id}", response_model=GameResponse)
async def retrieve(
    game_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    game = await get_game(db, game_id)
    if not game or game.club_id != _require_club(current_user):
        deny_not_found("Game")
    return game


@router.patch("/{game_id}/broadcast-message", response_model=GameResponse)
async def update_game_broadcast_message(
    game_id: uuid.UUID,
    data: GameBroadcastMessageUpdate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    game = await get_game(db, game_id)
    if not game or not await can_operate_game(db, current_user, game):
        deny_not_found("Game")
    updated = await update_broadcast_message(db, game_id, data.message)
    if not updated:
        deny_not_found("Game")
    return updated


@router.patch("/{game_id}", response_model=GameResponse)
async def update(
    game_id: uuid.UUID,
    data: GameUpdate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    game = await get_game(db, game_id)
    if not game or not await can_operate_game(db, current_user, game):
        deny_not_found("Game")
    try:
        updated = await update_game(db, game_id, data)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    if not updated:
        deny_not_found("Game")
    return updated
