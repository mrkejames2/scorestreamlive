"""ScoringEvent REST API routes."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models.game import Game
from app.schemas.scoring_event import ScoringEventCreate, ScoringEventResponse
from app.services.scoring_service import create_scoring_event, get_game_scoring_events

router = APIRouter(prefix="/api", tags=["scoring"])


@router.post(
    "/scoring-events",
    response_model=ScoringEventResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create(
    data: ScoringEventCreate,
    db: AsyncSession = Depends(get_session),
):
    """Record a scoring event and atomically increment the Game score."""
    try:
        return await create_scoring_event(db, data)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e)
        )


@router.get(
    "/games/{game_id}/scoring-events",
    response_model=list[ScoringEventResponse],
)
async def list_scoring_events(
    game_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
):
    """Retrieve scoring history for a Game."""
    game = await db.get(Game, game_id)
    if not game:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Game not found"
        )
    return await get_game_scoring_events(db, game_id)