"""ScoringEvent REST API routes."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import can_operate_game, can_view_game, deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.game import Game
from app.models.scoring_event import ScoringEvent
from app.models.user import User
from app.schemas.scoring_event import ScoringEventCreate, ScoringEventResponse, ScoringEventUpdate
from app.services.scoring_service import create_scoring_event, delete_scoring_event, get_game_scoring_events, update_scoring_event_scorer

router = APIRouter(prefix="/api", tags=["scoring"])


async def _require_event_operator(
    db: AsyncSession,
    current_user: User,
    event_id: uuid.UUID,
) -> None:
    event = await db.get(ScoringEvent, event_id)
    if not event:
        deny_not_found("Scoring event")

    game = await db.get(Game, event.game_id)
    if not game or not await can_operate_game(db, current_user, game):
        deny_not_found("Scoring event")

    if game.archived_at is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Archived Games are read-only")


@router.post(
    "/scoring-events",
    response_model=ScoringEventResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create(
    data: ScoringEventCreate,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Record a scoring event and atomically increment the Game score."""
    require_same_origin_mutation(request)

    game = await db.get(Game, data.game_id)
    if not game or not await can_operate_game(db, current_user, game):
        deny_not_found("Game")

    if game.archived_at is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Archived Games are read-only")

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
async def update_scorer(
    event_id: uuid.UUID,
    data: ScoringEventUpdate,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    require_same_origin_mutation(request)
    await _require_event_operator(db, current_user, event_id)

    try:
        return await update_scoring_event_scorer(db, event_id, data.player_id)
    except ValueError as e:
        code = status.HTTP_404_NOT_FOUND if str(e) == "Scoring event not found" else status.HTTP_422_UNPROCESSABLE_ENTITY
        raise HTTPException(status_code=code, detail=str(e))


@router.delete(
    "/scoring-events/{event_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_goal(
    event_id: uuid.UUID,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    require_same_origin_mutation(request)
    await _require_event_operator(db, current_user, event_id)

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
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Retrieve scoring history for a Game."""
    game = await db.get(Game, game_id)
    if not game or not await can_view_game(db, current_user, game):
        deny_not_found("Game")

    return await get_game_scoring_events(db, game_id)
