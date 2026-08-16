"""GameLifecycle REST API with M9-D post-commit events."""

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.encoders import jsonable_encoder
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.schemas.game_lifecycle import (
    GameLifecycleCreate,
    GameLifecycleResponse,
    GameLifecycleTransition,
    GameLifecycleTransitionResponse,
)
from app.services.game_lifecycle_service import (
    LifecycleConflictError,
    LifecycleNotFoundError,
    create_lifecycle,
    get_lifecycle,
    serialize_lifecycle_state,
    transition_lifecycle,
)
from app.sockets import sio


router = APIRouter(prefix="/api", tags=["lifecycle"])
logger = logging.getLogger("app")


def _not_found(exc: LifecycleNotFoundError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=str(exc),
    )


def _conflict(exc: LifecycleConflictError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=str(exc),
    )


@router.post(
    "/games/{game_id}/lifecycle",
    response_model=GameLifecycleResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_game_lifecycle(
    game_id: uuid.UUID,
    _: GameLifecycleCreate,
    db: AsyncSession = Depends(get_session),
):
    try:
        lifecycle = await create_lifecycle(db, game_id)
    except LifecycleNotFoundError as exc:
        raise _not_found(exc)
    except LifecycleConflictError as exc:
        raise _conflict(exc)

    return lifecycle


@router.get(
    "/games/{game_id}/lifecycle",
    response_model=GameLifecycleResponse,
)
async def get_game_lifecycle(
    game_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
):
    lifecycle = await get_lifecycle(db, game_id)

    if not lifecycle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lifecycle not found",
        )

    return lifecycle


@router.post(
    "/games/{game_id}/lifecycle/transition",
    response_model=GameLifecycleTransitionResponse,
)
async def transition_game_lifecycle(
    game_id: uuid.UUID,
    data: GameLifecycleTransition,
    db: AsyncSession = Depends(get_session),
):
    try:
        lifecycle, clock_state = await transition_lifecycle(
            db,
            game_id,
            data,
        )
    except LifecycleNotFoundError as exc:
        raise _not_found(exc)
    except LifecycleConflictError as exc:
        raise _conflict(exc)

    # The lifecycle + clock transaction has already committed successfully.
    #
    # transition_id is transport-only correlation metadata. It allows
    # connected clients to recognize that game:phase_updated and
    # clock:updated came from the same atomic Game transition.
    transition_id = uuid.uuid4()

    lifecycle_event = serialize_lifecycle_state(lifecycle)
    lifecycle_event["transition_id"] = str(transition_id)

    clock_event = dict(clock_state)
    clock_event["transition_id"] = str(transition_id)

    # Convert the COMPLETE Socket.IO payloads to JSON-safe values.
    #
    # This safely handles:
    # - UUID
    # - datetime
    # - nested values
    #
    # Do not manually convert individual fields.
    lifecycle_event = jsonable_encoder(lifecycle_event)
    clock_event = jsonable_encoder(clock_event)

    # Deterministic post-commit ordering:
    #
    # 1. Game lifecycle meaning
    # 2. Matching clock state
    #
    # Both describe state that is already committed to PostgreSQL.
    try:
        await sio.emit(
            "game:phase_updated",
            lifecycle_event,
        )

        await sio.emit(
            "clock:updated",
            clock_event,
        )

    except Exception:
        # Socket.IO is not the persistence boundary.
        #
        # The database transaction already committed, so a transport
        # failure must not convert a successful business transaction
        # into an HTTP 500 or roll back committed state.
        #
        # Validation will detect missing real-time events.
        logger.exception(
            "Failed to emit M9 lifecycle transition events",
            extra={
                "event": "lifecycle.socket_emit.failure",
                "game_id": str(game_id),
                "transition_id": str(transition_id),
                "lifecycle_version": lifecycle.version,
                "clock_version": clock_state["version"],
            },
        )

    return {
        "transition_id": transition_id,
        "lifecycle": lifecycle,
        "clock": clock_state,
    }