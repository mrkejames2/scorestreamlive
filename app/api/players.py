"""Player REST API routes."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.schemas.player import PlayerCreate, PlayerUpdate, PlayerResponse
from app.services.player_service import create_player, get_player, update_player

router = APIRouter(prefix="/api/players", tags=["players"])


@router.post("", response_model=PlayerResponse, status_code=status.HTTP_201_CREATED)
async def create(
    data: PlayerCreate,
    db: AsyncSession = Depends(get_session),
):
    """Create a new Player."""
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
    db: AsyncSession = Depends(get_session),
):
    """Retrieve a single Player by ID."""
    player = await get_player(db, player_id)
    if not player:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player not found",
        )
    return player


@router.patch("/{player_id}", response_model=PlayerResponse)
async def update(
    player_id: uuid.UUID,
    data: PlayerUpdate,
    db: AsyncSession = Depends(get_session),
):
    """Update an existing Player."""
    try:
        player = await update_player(db, player_id, data)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e),
        )
    if not player:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Player not found",
        )
    return player