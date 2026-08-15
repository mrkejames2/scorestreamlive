"""GameClock REST API routes."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
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


@router.post(
    "/games/{game_id}/clock",
    response_model=GameClockResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_game_clock(
    game_id: uuid.UUID,
    data: GameClockCreate,
    db: AsyncSession = Depends(get_session),
):
    """Initialize a GameClock."""

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
    db: AsyncSession = Depends(get_session),
):
    """Return authoritative GameClock state and derived current time."""

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
    db: AsyncSession = Depends(get_session),
):
    """Update clock mode/duration while the clock is not running."""

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
    db: AsyncSession = Depends(get_session),
):
    """Start a stopped clock."""

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
    db: AsyncSession = Depends(get_session),
):
    """Pause a running clock."""

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
    db: AsyncSession = Depends(get_session),
):
    """Resume a paused clock."""

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
    db: AsyncSession = Depends(get_session),
):
    """Reset a paused/stopped clock."""

    try:
        clock = await reset_clock(db, game_id, data.expected_version)
    except ClockNotFoundError as exc:
        raise _not_found(exc)
    except ClockConflictError as exc:
        raise _conflict(exc)

    return serialize_clock_state(clock)
