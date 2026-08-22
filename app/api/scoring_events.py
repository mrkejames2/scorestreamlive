"""ScoringEvent REST API routes."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models.game import Game
from app.schemas.scoring_event import ScoringEventCreate, ScoringEventResponse, ScoringEventUpdate
from app.services.scoring_service import create_scoring_event, delete_scoring_event, get_game_scoring_events, update_scoring_event_scorer

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


@router.patch(
    "/scoring-events/{event_id}",
    response_model=ScoringEventResponse,
)
async def update_scorer(event_id: uuid.UUID, data: ScoringEventUpdate, db: AsyncSession = Depends(get_session)):
    try:
        return await update_scoring_event_scorer(db, event_id, data.player_id)
    except ValueError as e:
        code = status.HTTP_404_NOT_FOUND if str(e) == "Scoring event not found" else status.HTTP_422_UNPROCESSABLE_ENTITY
        raise HTTPException(status_code=code, detail=str(e))


@router.delete(
    "/scoring-events/{event_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_goal(event_id: uuid.UUID, db: AsyncSession = Depends(get_session)):
    try:
        await delete_scoring_event(db, event_id)
    except ValueError as e:
        code = status.HTTP_404_NOT_FOUND if str(e) == "Scoring event not found" else status.HTTP_422_UNPROCESSABLE_ENTITY
        raise HTTPException(status_code=code, detail=str(e))


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