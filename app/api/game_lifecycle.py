"""GameLifecycle REST API with M9-D post-commit events."""

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.encoders import jsonable_encoder
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import can_operate_game, can_view_game, deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.game import Game
from app.models.user import User
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
    "/games/{game_id}/lifecycle",
    response_model=GameLifecycleResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_game_lifecycle(
    game_id: uuid.UUID,
    _: GameLifecycleCreate,
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    require_same_origin_mutation(request)
    await _require_game_access(db, current_user, game_id, operate=True)

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
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    await _require_game_access(db, current_user, game_id, operate=False)

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
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    require_same_origin_mutation(request)
    await _require_game_access(db, current_user, game_id, operate=True)

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

    transition_id = uuid.uuid4()

    lifecycle_event = serialize_lifecycle_state(lifecycle)
    lifecycle_event["transition_id"] = str(transition_id)

    clock_event = dict(clock_state)
    clock_event["transition_id"] = str(transition_id)

    lifecycle_event = jsonable_encoder(lifecycle_event)
    clock_event = jsonable_encoder(clock_event)

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
