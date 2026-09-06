"""Club- and role-scoped Game REST API routes for M15-D."""

import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import (
    can_create_game_with_teams,
    can_operate_game,
    can_view_game,
    deny_not_found,
    visible_game_ids,
)
from app.auth.dependencies import require_current_user
from app.auth.roles import ClubRole
from app.database import get_session
from app.models.user import User
from app.schemas.game import (
    GameBroadcastMessageUpdate,
    GameCreate,
    GameResponse,
    GameUpdate,
)
from app.services.game_service import (
    create_game,
    get_game,
    list_games,
    update_broadcast_message,
    update_game,
)
from app.services.resource_lifecycle_service import LifecycleConflict, archive_game, hard_delete_game, restore_game

router = APIRouter(prefix="/api/games", tags=["games"])


def _require_club(user: User) -> uuid.UUID:
    if user.club_id is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User is not assigned to a Club",
        )
    return user.club_id


@router.post(
    "",
    response_model=GameResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create(
    data: GameCreate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    club_id = _require_club(current_user)

    if current_user.club_role not in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permission",
        )

    allowed = await can_create_game_with_teams(
        db,
        current_user,
        data.home_team_id,
        data.away_team_id,
    )
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Game Teams are outside your assigned access",
        )

    try:
        return await create_game(db, data, club_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )


@router.get("", response_model=list[GameResponse])
async def list_all(
    limit: Optional[int] = Query(default=None, ge=1, le=100),
    archived: bool = Query(default=False),
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    games = await list_games(
        db,
        limit=None,
        club_id=_require_club(current_user),
        archived=archived,
    )

    visible_ids = await visible_game_ids(db, current_user)
    if visible_ids is not None:
        games = [
            game
            for game in games
            if game.id in visible_ids
        ]

    if limit is not None:
        return games[:limit]
    return games




async def _manageable_game(game_id: uuid.UUID, current_user: User, db: AsyncSession):
    if current_user.club_role not in {ClubRole.DIRECTOR.value, ClubRole.MANAGER.value}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permission")
    game = await get_game(db, game_id)
    if not game or not await can_operate_game(db, current_user, game):
        deny_not_found("Game")
    return game

@router.post("/{game_id}/archive", response_model=GameResponse)
async def archive(game_id: uuid.UUID, current_user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    return await archive_game(db, await _manageable_game(game_id, current_user, db))

@router.post("/{game_id}/restore", response_model=GameResponse)
async def restore(game_id: uuid.UUID, current_user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    return await restore_game(db, await _manageable_game(game_id, current_user, db))

@router.delete("/{game_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove(game_id: uuid.UUID, current_user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    game = await _manageable_game(game_id, current_user, db)
    try:
        await hard_delete_game(db, game)
    except LifecycleConflict as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc))
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@router.get("/{game_id}", response_model=GameResponse)
async def retrieve(
    game_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    game = await get_game(db, game_id)
    if not game or not await can_view_game(
        db,
        current_user,
        game,
    ):
        deny_not_found("Game")
    return game


@router.patch(
    "/{game_id}/broadcast-message",
    response_model=GameResponse,
)
async def update_game_broadcast_message(
    game_id: uuid.UUID,
    data: GameBroadcastMessageUpdate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    game = await get_game(db, game_id)
    if not game or not await can_operate_game(
        db,
        current_user,
        game,
    ):
        deny_not_found("Game")

    if game.archived_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Archived Games are read-only",
        )

    updated = await update_broadcast_message(
        db,
        game_id,
        data.message,
    )
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
    if not game or not await can_operate_game(
        db,
        current_user,
        game,
    ):
        deny_not_found("Game")

    if game.archived_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Archived Games are read-only",
        )

    try:
        updated = await update_game(
            db,
            game_id,
            data,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )

    if not updated:
        deny_not_found("Game")
    return updated
