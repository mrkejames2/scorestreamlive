"""Player REST API routes."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import can_manage_team, can_view_team, deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.team import Team
from app.models.user import User
from app.schemas.player import PlayerCreate, PlayerUpdate, PlayerResponse
from app.services.player_service import create_player, get_player, update_player

router = APIRouter(prefix="/api/players", tags=["players"])


@router.post("", response_model=PlayerResponse, status_code=status.HTTP_201_CREATED)
async def create(
    data: PlayerCreate,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Create a new Player."""
    require_same_origin_mutation(request)

    team = await db.get(Team, data.team_id)
    if not team or not await can_manage_team(db, current_user, team):
        deny_not_found("Team")

    if team.archived_at is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Archived Teams are read-only")

    try:
        return await create_player(db, data)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e),
        )


@router.get("/{player_id}", response_model=PlayerResponse)
async def retrieve(
    player_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Retrieve a single Player by ID."""
    player = await get_player(db, player_id)
    if not player:
        deny_not_found("Player")

    team = await db.get(Team, player.team_id)
    if not team or not await can_view_team(db, current_user, team):
        deny_not_found("Player")

    return player


@router.patch("/{player_id}", response_model=PlayerResponse)
async def update(
    player_id: uuid.UUID,
    data: PlayerUpdate,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Update an existing Player."""
    require_same_origin_mutation(request)

    player = await get_player(db, player_id)
    if not player:
        deny_not_found("Player")

    team = await db.get(Team, player.team_id)
    if not team or not await can_manage_team(db, current_user, team):
        deny_not_found("Player")

    if team.archived_at is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Archived Teams are read-only")

    try:
        player = await update_player(db, player_id, data)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e),
        )
    if not player:
        deny_not_found("Player")
    return player
