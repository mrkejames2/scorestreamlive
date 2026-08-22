"""Game REST API routes."""

import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.schemas.game import GameCreate, GameUpdate, GameResponse
from app.services.game_service import create_game, list_games, get_game, update_game

router = APIRouter(prefix="/api/games", tags=["games"])


@router.post("", response_model=GameResponse, status_code=status.HTTP_201_CREATED)
async def create(
    data: GameCreate,
    db: AsyncSession = Depends(get_session),
):
    """Create a new Game."""
    try:
        return await create_game(db, data)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))


@router.get("", response_model=list[GameResponse])
async def list_all(
    limit: Optional[int] = Query(
        default=None,
        ge=1,
        le=100,
    ),
    db: AsyncSession = Depends(get_session),
):
    """List Games, optionally bounded for dashboard retrieval."""
    return await list_games(db, limit=limit)


@router.get("/{game_id}", response_model=GameResponse)
async def retrieve(
    game_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
):
    """Retrieve a single Game by ID."""
    game = await get_game(db, game_id)
    if not game:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Game not found")
    return game


@router.patch("/{game_id}", response_model=GameResponse)
async def update(
    game_id: uuid.UUID,
    data: GameUpdate,
    db: AsyncSession = Depends(get_session),
):
    """Update an existing Game."""
    try:
        game = await update_game(db, game_id, data)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    if not game:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Game not found")
    return game