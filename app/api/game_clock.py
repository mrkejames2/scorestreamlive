"""GameClock REST API routes."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import can_operate_game, can_view_game, deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.game import Game
from app.models.user import User
from app.schemas.game_clock import (
    GameClockCommand,
    GameClockCreate,
    GameClockResponse,
    GameClockUpdate,
)
from app.services.game_clock_service import (
    ClockConflictError,
    ClockNotFoundError,
    create_clock,
    get_clock,
    pause_clock,
    reset_clock,
    resume_clock,
    serialize_clock_state,
    start_clock,
    update_clock_configuration,
)


router = APIRouter(prefix="/api", tags=["clock"])


def _not_found(exc: ClockNotFoundError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=str(exc),
    )


def _conflict(exc: ClockConflictError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=str(exc),
    )


async def _require_game_access(
    db: AsyncSession,
    current_user: User,
    game_id: uuid.UUID,
    *,
    operate: bool,
) -> None:
    game = await db.get(Game, game_id)
    if not game:
        deny_not_found("Game")

    allowed = (
        await can_operate_game(db, current_user, game)
        if operate
        else await can_view_game(db, current_user, game)
    )
    if not allowed:
        deny_not_found("Game")

    if operate and game.archived_at is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Archived Games are read-only")


@router.post(
    "/games/{game_id}/clock",
    response_model=GameClockResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_game_clock(
    game_id: uuid.UUID,
    data: GameClockCreate,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Initialize a GameClock."""
    require_same_origin_mutation(request)
    await _require_game_access(db, current_user, game_id, operate=True)

    try:
        clock = await create_clock(db, game_id, data)
    except ClockNotFoundError as exc:
        raise _not_found(exc)
    except ClockConflictError as exc:
        raise _conflict(exc)

    return serialize_clock_state(clock)


@router.get(
    "/games/{game_id}/clock",
    response_model=GameClockResponse,
)
async def get_game_clock(
    game_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Return authoritative GameClock state and derived current time."""
    await _require_game_access(db, current_user, game_id, operate=False)

    clock = await get_clock(db, game_id)

    if not clock:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Clock not found",
        )

    return serialize_clock_state(clock)


@router.patch(
    "/games/{game_id}/clock",
    response_model=GameClockResponse,
)
async def configure_game_clock(
    game_id: uuid.UUID,
    data: GameClockUpdate,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Update clock mode/duration while the clock is not running."""
    require_same_origin_mutation(request)
    await _require_game_access(db, current_user, game_id, operate=True)

    try:
        clock = await update_clock_configuration(db, game_id, data)
    except ClockNotFoundError as exc:
        raise _not_found(exc)
    except ClockConflictError as exc:
        raise _conflict(exc)

    return serialize_clock_state(clock)


@router.post(
    "/games/{game_id}/clock/start",
    response_model=GameClockResponse,
)
async def start_game_clock(
    game_id: uuid.UUID,
    data: GameClockCommand,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Start a stopped clock."""
    require_same_origin_mutation(request)
    await _require_game_access(db, current_user, game_id, operate=True)

    try:
        clock = await start_clock(db, game_id, data.expected_version)
    except ClockNotFoundError as exc:
        raise _not_found(exc)
    except ClockConflictError as exc:
        raise _conflict(exc)

    return serialize_clock_state(clock)


@router.post(
    "/games/{game_id}/clock/pause",
    response_model=GameClockResponse,
)
async def pause_game_clock(
    game_id: uuid.UUID,
    data: GameClockCommand,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Pause a running clock."""
    require_same_origin_mutation(request)
    await _require_game_access(db, current_user, game_id, operate=True)

    try:
        clock = await pause_clock(db, game_id, data.expected_version)
    except ClockNotFoundError as exc:
        raise _not_found(exc)
    except ClockConflictError as exc:
        raise _conflict(exc)

    return serialize_clock_state(clock)


@router.post(
    "/games/{game_id}/clock/resume",
    response_model=GameClockResponse,
)
async def resume_game_clock(
    game_id: uuid.UUID,
    data: GameClockCommand,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Resume a paused clock."""
    require_same_origin_mutation(request)
    await _require_game_access(db, current_user, game_id, operate=True)

    try:
        clock = await resume_clock(db, game_id, data.expected_version)
    except ClockNotFoundError as exc:
        raise _not_found(exc)
    except ClockConflictError as exc:
        raise _conflict(exc)

    return serialize_clock_state(clock)


@router.post(
    "/games/{game_id}/clock/reset",
    response_model=GameClockResponse,
)
async def reset_game_clock(
    game_id: uuid.UUID,
    data: GameClockCommand,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    """Reset a paused/stopped clock."""
    require_same_origin_mutation(request)
    await _require_game_access(db, current_user, game_id, operate=True)

    try:
        clock = await reset_clock(db, game_id, data.expected_version)
    except ClockNotFoundError as exc:
        raise _not_found(exc)
    except ClockConflictError as exc:
        raise _conflict(exc)

    return serialize_clock_state(clock)
