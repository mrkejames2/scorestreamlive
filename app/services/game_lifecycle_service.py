"""GameLifecycle service layer.

M9-C established the atomic GameLifecycle + GameClock transaction.
M9-D keeps that transaction unchanged and adds post-commit event delivery
from the API layer.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.game import Game
from app.models.game_clock import GameClock
from app.models.game_lifecycle import GameLifecycle
from app.schemas.game_lifecycle import GameLifecycleTransition, LifecycleAction
from app.services.game_clock_service import (
    calculate_authoritative_elapsed_seconds,
    serialize_clock_state,
)


class LifecycleNotFoundError(Exception):
    pass


class LifecycleConflictError(Exception):
    pass


TRANSITIONS = {
    ("pregame", LifecycleAction.START_FIRST_HALF.value): "first_half",
    ("first_half", LifecycleAction.END_FIRST_HALF.value): "halftime",
    ("halftime", LifecycleAction.START_SECOND_HALF.value): "second_half",
    ("second_half", LifecycleAction.END_GAME.value): "full_time",
}


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def serialize_lifecycle_state(lifecycle: GameLifecycle) -> dict:
    """Serialize committed lifecycle state for REST/Socket.IO."""

    return {
        "id": str(lifecycle.id),
        "game_id": str(lifecycle.game_id),
        "phase": lifecycle.phase,
        "version": lifecycle.version,
        "created_at": lifecycle.created_at.isoformat(),
        "updated_at": lifecycle.updated_at.isoformat(),
    }


async def get_lifecycle(
    db: AsyncSession,
    game_id: uuid.UUID,
) -> GameLifecycle | None:
    result = await db.execute(
        select(GameLifecycle).where(GameLifecycle.game_id == game_id)
    )
    return result.scalar_one_or_none()


async def _get_lifecycle_or_raise(
    db: AsyncSession,
    game_id: uuid.UUID,
) -> GameLifecycle:
    lifecycle = await get_lifecycle(db, game_id)
    if not lifecycle:
        raise LifecycleNotFoundError("Lifecycle not found")
    return lifecycle


async def _get_clock_or_raise(
    db: AsyncSession,
    game_id: uuid.UUID,
) -> GameClock:
    result = await db.execute(
        select(GameClock).where(GameClock.game_id == game_id)
    )
    clock = result.scalar_one_or_none()
    if not clock:
        raise LifecycleNotFoundError("Clock not found")
    return clock


async def _reload_lifecycle(
    db: AsyncSession,
    game_id: uuid.UUID,
) -> GameLifecycle:
    result = await db.execute(
        select(GameLifecycle).where(GameLifecycle.game_id == game_id)
    )
    return result.scalar_one()


async def _reload_clock(
    db: AsyncSession,
    game_id: uuid.UUID,
) -> GameClock:
    result = await db.execute(
        select(GameClock).where(GameClock.game_id == game_id)
    )
    return result.scalar_one()


async def create_lifecycle(
    db: AsyncSession,
    game_id: uuid.UUID,
) -> GameLifecycle:
    game = await db.get(Game, game_id)
    if not game:
        raise LifecycleNotFoundError("Game not found")

    now = _utc_now()
    lifecycle = GameLifecycle(
        game_id=game_id,
        phase="pregame",
        version=1,
        created_at=now,
        updated_at=now,
    )
    db.add(lifecycle)

    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise LifecycleConflictError(
            "Lifecycle already exists for this Game"
        )

    await db.refresh(lifecycle)
    return lifecycle


def _build_clock_values(
    action: LifecycleAction,
    clock: GameClock,
    now: datetime,
) -> tuple[dict, str]:
    if action == LifecycleAction.START_FIRST_HALF:
        if clock.status == "running":
            raise LifecycleConflictError(
                "Clock must not be running before first half starts"
            )

        return (
            {
                "mode": "count_up",
                "status": "running",
                "duration_seconds": 2700,
                "elapsed_seconds": 0,
                "running_since": now,
                "updated_at": now,
            },
            "not_running",
        )

    if action == LifecycleAction.END_FIRST_HALF:
        if clock.status != "running":
            raise LifecycleConflictError(
                "Clock must be running to end first half"
            )

        return (
            {
                "status": "paused",
                "elapsed_seconds": calculate_authoritative_elapsed_seconds(
                    clock,
                    now,
                ),
                "running_since": None,
                "updated_at": now,
            },
            "running",
        )

    if action == LifecycleAction.START_SECOND_HALF:
        if clock.status == "running":
            raise LifecycleConflictError(
                "Clock must not be running before second half starts"
            )

        return (
            {
                "mode": "count_up",
                "status": "running",
                "duration_seconds": 5400,
                "elapsed_seconds": 2700,
                "running_since": now,
                "updated_at": now,
            },
            "not_running",
        )

    if action == LifecycleAction.END_GAME:
        if clock.status != "running":
            raise LifecycleConflictError(
                "Clock must be running to end the Game"
            )

        return (
            {
                "status": "paused",
                "elapsed_seconds": calculate_authoritative_elapsed_seconds(
                    clock,
                    now,
                ),
                "running_since": None,
                "updated_at": now,
            },
            "running",
        )

    raise LifecycleConflictError("Unsupported lifecycle action")


async def transition_lifecycle(
    db: AsyncSession,
    game_id: uuid.UUID,
    data: GameLifecycleTransition,
) -> tuple[GameLifecycle, dict]:
    """Atomically transition lifecycle and clock with one commit."""

    lifecycle = await _get_lifecycle_or_raise(db, game_id)
    clock = await _get_clock_or_raise(db, game_id)

    if lifecycle.version != data.expected_lifecycle_version:
        raise LifecycleConflictError(
            "Lifecycle version conflict; refetch current state"
        )

    if clock.version != data.expected_clock_version:
        raise LifecycleConflictError(
            "Clock version conflict; refetch current state"
        )

    next_phase = TRANSITIONS.get(
        (lifecycle.phase, data.action.value)
    )
    if next_phase is None:
        raise LifecycleConflictError(
            f"Action {data.action.value} is not allowed from phase "
            f"{lifecycle.phase}"
        )

    now = _utc_now()
    clock_values, clock_status_rule = _build_clock_values(
        data.action,
        clock,
        now,
    )

    lifecycle_result = await db.execute(
        update(GameLifecycle)
        .where(
            GameLifecycle.game_id == game_id,
            GameLifecycle.version == data.expected_lifecycle_version,
            GameLifecycle.phase == lifecycle.phase,
        )
        .values(
            phase=next_phase,
            version=data.expected_lifecycle_version + 1,
            updated_at=now,
        )
    )

    if lifecycle_result.rowcount != 1:
        await db.rollback()
        raise LifecycleConflictError(
            "Lifecycle changed before transition; refetch current state"
        )

    clock_conditions = [
        GameClock.game_id == game_id,
        GameClock.version == data.expected_clock_version,
    ]

    if clock_status_rule == "running":
        clock_conditions.append(GameClock.status == "running")
    else:
        clock_conditions.append(GameClock.status != "running")

    clock_values["version"] = data.expected_clock_version + 1

    clock_result = await db.execute(
        update(GameClock)
        .where(*clock_conditions)
        .values(**clock_values)
    )

    if clock_result.rowcount != 1:
        await db.rollback()
        raise LifecycleConflictError(
            "Clock changed before transition; no lifecycle change committed"
        )

    await db.commit()

    committed_lifecycle = await _reload_lifecycle(db, game_id)
    committed_clock = await _reload_clock(db, game_id)
    clock_state = serialize_clock_state(committed_clock, _utc_now())

    return committed_lifecycle, clock_state
