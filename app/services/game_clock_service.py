"""GameClock service layer."""

import logging
import math
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.game import Game
from app.models.game_clock import GameClock
from app.schemas.game_clock import (
    ClockMode,
    GameClockCreate,
    GameClockUpdate,
)
from app.sockets import sio


logger = logging.getLogger("app")


class ClockNotFoundError(Exception):
    """Requested GameClock or parent Game does not exist."""


class ClockConflictError(Exception):
    """Clock state conflicts with the requested transition."""


def _utc_now() -> datetime:
    """Return an aware UTC timestamp.

    Kept behind one helper so the clock has one time-source boundary.
    """

    return datetime.now(timezone.utc)


def calculate_authoritative_elapsed_seconds(
    clock: GameClock,
    now: Optional[datetime] = None,
) -> int:
    """Calculate current elapsed seconds from persisted state and anchor."""

    current_time = now or _utc_now()

    if clock.status != "running" or clock.running_since is None:
        return clock.elapsed_seconds

    delta_seconds = math.floor(
        (current_time - clock.running_since).total_seconds()
    )

    # Protect elapsed duration from a backwards wall-clock adjustment.
    delta_seconds = max(delta_seconds, 0)

    return clock.elapsed_seconds + delta_seconds


def calculate_display_seconds(
    mode: str,
    duration_seconds: int,
    authoritative_elapsed_seconds: int,
) -> int:
    """Return the generic displayed time in seconds."""

    if mode == ClockMode.COUNT_UP.value:
        return authoritative_elapsed_seconds

    return max(
        duration_seconds - authoritative_elapsed_seconds,
        0,
    )


def calculate_soccer_added_time_minute(
    authoritative_elapsed_seconds: int,
    duration_seconds: int,
) -> Optional[int]:
    """Derive soccer elapsed added-time minute from generic clock state.

    This does not represent referee-announced stoppage time.
    """

    if authoritative_elapsed_seconds < duration_seconds:
        return None

    return (
        (authoritative_elapsed_seconds - duration_seconds) // 60
    ) + 1


def serialize_clock_state(
    clock: GameClock,
    now: Optional[datetime] = None,
) -> dict:
    """Return public authoritative clock state and synchronization metadata."""

    server_time = now or _utc_now()

    authoritative_elapsed = calculate_authoritative_elapsed_seconds(
        clock,
        server_time,
    )

    return {
        "id": clock.id,
        "game_id": clock.game_id,
        "mode": clock.mode,
        "status": clock.status,
        "duration_seconds": clock.duration_seconds,
        "elapsed_seconds": clock.elapsed_seconds,
        "running_since": clock.running_since,
        "version": clock.version,
        "created_at": clock.created_at,
        "updated_at": clock.updated_at,
        "server_time": server_time,
        "authoritative_elapsed_seconds": authoritative_elapsed,
        "display_seconds": calculate_display_seconds(
            clock.mode,
            clock.duration_seconds,
            authoritative_elapsed,
        ),
    }


def _serialize_clock_socket_state(
    clock: GameClock,
    now: Optional[datetime] = None,
) -> dict:
    """Return JSON-safe authoritative clock state for Socket.IO."""

    state = serialize_clock_state(clock, now)

    return {
        "id": str(state["id"]),
        "game_id": str(state["game_id"]),
        "mode": state["mode"],
        "status": state["status"],
        "duration_seconds": state["duration_seconds"],
        "elapsed_seconds": state["elapsed_seconds"],
        "running_since": (
            state["running_since"].isoformat()
            if state["running_since"] is not None
            else None
        ),
        "version": state["version"],
        "created_at": state["created_at"].isoformat(),
        "updated_at": state["updated_at"].isoformat(),
        "server_time": state["server_time"].isoformat(),
        "authoritative_elapsed_seconds": state[
            "authoritative_elapsed_seconds"
        ],
        "display_seconds": state["display_seconds"],
    }


async def _emit_clock_updated(
    clock: GameClock,
    action: str,
) -> None:
    """Emit one committed GameClock snapshot after a successful mutation."""

    payload = _serialize_clock_socket_state(clock)

    await sio.emit(
        "clock:updated",
        payload,
    )

    logger.info(
        "Clock state committed — game_id=%s clock_id=%s action=%s version=%s status=%s",
        clock.game_id,
        clock.id,
        action,
        clock.version,
        clock.status,
        extra={
            "event": "clock.updated",
            "game_id": str(clock.game_id),
            "clock_id": str(clock.id),
            "clock_action": action,
            "clock_version": clock.version,
            "clock_status": clock.status,
        },
    )


async def get_clock(
    db: AsyncSession,
    game_id: uuid.UUID,
) -> Optional[GameClock]:
    """Return a GameClock by Game ID, or None."""

    result = await db.execute(
        select(GameClock).where(GameClock.game_id == game_id)
    )
    return result.scalar_one_or_none()


async def _get_clock_or_raise(
    db: AsyncSession,
    game_id: uuid.UUID,
) -> GameClock:
    """Return a GameClock or raise the service's not-found error."""

    clock = await get_clock(db, game_id)

    if not clock:
        raise ClockNotFoundError("Clock not found")

    return clock


def _validate_expected_version(
    clock: GameClock,
    expected_version: int,
) -> None:
    """Reject a controller whose state is already stale."""

    if clock.version != expected_version:
        raise ClockConflictError(
            "Clock version conflict; refetch current clock state"
        )


async def _reload_clock(
    db: AsyncSession,
    game_id: uuid.UUID,
) -> GameClock:
    """Reload committed GameClock state."""

    result = await db.execute(
        select(GameClock).where(GameClock.game_id == game_id)
    )
    return result.scalar_one()


async def create_clock(
    db: AsyncSession,
    game_id: uuid.UUID,
    data: GameClockCreate,
) -> GameClock:
    """Initialize the single GameClock for a Game."""

    game = await db.get(Game, game_id)

    if not game:
        raise ClockNotFoundError("Game not found")

    now = _utc_now()

    clock = GameClock(
        game_id=game_id,
        mode=data.mode.value,
        status="stopped",
        duration_seconds=data.duration_seconds,
        elapsed_seconds=0,
        running_since=None,
        version=1,
        created_at=now,
        updated_at=now,
    )

    db.add(clock)

    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise ClockConflictError("Clock already exists for this Game")

    await db.refresh(clock)

    # M8-C: committed-state notification only after successful commit.
    await _emit_clock_updated(clock, "created")

    return clock


async def update_clock_configuration(
    db: AsyncSession,
    game_id: uuid.UUID,
    data: GameClockUpdate,
) -> GameClock:
    """Update mode/duration with optimistic concurrency."""

    clock = await _get_clock_or_raise(db, game_id)
    _validate_expected_version(clock, data.expected_version)

    if clock.status == "running":
        raise ClockConflictError(
            "Clock configuration cannot change while running"
        )

    now = _utc_now()

    values = {
        "version": data.expected_version + 1,
        "updated_at": now,
    }

    if data.mode is not None:
        values["mode"] = data.mode.value

    if data.duration_seconds is not None:
        values["duration_seconds"] = data.duration_seconds

    result = await db.execute(
        update(GameClock)
        .where(
            GameClock.game_id == game_id,
            GameClock.version == data.expected_version,
            GameClock.status != "running",
        )
        .values(**values)
    )

    if result.rowcount != 1:
        await db.rollback()
        raise ClockConflictError(
            "Clock changed before configuration update; refetch current state"
        )

    await db.commit()
    clock = await _reload_clock(db, game_id)

    await _emit_clock_updated(clock, "configured")

    return clock


async def start_clock(
    db: AsyncSession,
    game_id: uuid.UUID,
    expected_version: int,
) -> GameClock:
    """Start a stopped clock."""

    clock = await _get_clock_or_raise(db, game_id)
    _validate_expected_version(clock, expected_version)

    if clock.status != "stopped":
        raise ClockConflictError("Clock can only start from stopped")

    now = _utc_now()

    result = await db.execute(
        update(GameClock)
        .where(
            GameClock.game_id == game_id,
            GameClock.version == expected_version,
            GameClock.status == "stopped",
        )
        .values(
            status="running",
            running_since=now,
            version=expected_version + 1,
            updated_at=now,
        )
    )

    if result.rowcount != 1:
        await db.rollback()
        raise ClockConflictError(
            "Clock changed before start; refetch current state"
        )

    await db.commit()
    clock = await _reload_clock(db, game_id)

    await _emit_clock_updated(clock, "started")

    return clock


async def pause_clock(
    db: AsyncSession,
    game_id: uuid.UUID,
    expected_version: int,
) -> GameClock:
    """Pause a running clock and persist accumulated elapsed time."""

    clock = await _get_clock_or_raise(db, game_id)
    _validate_expected_version(clock, expected_version)

    if clock.status != "running":
        raise ClockConflictError("Clock can only pause while running")

    now = _utc_now()
    authoritative_elapsed = calculate_authoritative_elapsed_seconds(
        clock,
        now,
    )

    result = await db.execute(
        update(GameClock)
        .where(
            GameClock.game_id == game_id,
            GameClock.version == expected_version,
            GameClock.status == "running",
        )
        .values(
            elapsed_seconds=authoritative_elapsed,
            status="paused",
            running_since=None,
            version=expected_version + 1,
            updated_at=now,
        )
    )

    if result.rowcount != 1:
        await db.rollback()
        raise ClockConflictError(
            "Clock changed before pause; refetch current state"
        )

    await db.commit()
    clock = await _reload_clock(db, game_id)

    await _emit_clock_updated(clock, "paused")

    return clock


async def resume_clock(
    db: AsyncSession,
    game_id: uuid.UUID,
    expected_version: int,
) -> GameClock:
    """Resume a paused clock."""

    clock = await _get_clock_or_raise(db, game_id)
    _validate_expected_version(clock, expected_version)

    if clock.status != "paused":
        raise ClockConflictError("Clock can only resume from paused")

    now = _utc_now()

    result = await db.execute(
        update(GameClock)
        .where(
            GameClock.game_id == game_id,
            GameClock.version == expected_version,
            GameClock.status == "paused",
        )
        .values(
            status="running",
            running_since=now,
            version=expected_version + 1,
            updated_at=now,
        )
    )

    if result.rowcount != 1:
        await db.rollback()
        raise ClockConflictError(
            "Clock changed before resume; refetch current state"
        )

    await db.commit()
    clock = await _reload_clock(db, game_id)

    await _emit_clock_updated(clock, "resumed")

    return clock


async def reset_clock(
    db: AsyncSession,
    game_id: uuid.UUID,
    expected_version: int,
) -> GameClock:
    """Reset a stopped/paused clock while preserving mode/duration."""

    clock = await _get_clock_or_raise(db, game_id)
    _validate_expected_version(clock, expected_version)

    if clock.status == "running":
        raise ClockConflictError("Pause the clock before reset")

    now = _utc_now()

    result = await db.execute(
        update(GameClock)
        .where(
            GameClock.game_id == game_id,
            GameClock.version == expected_version,
            GameClock.status != "running",
        )
        .values(
            status="stopped",
            elapsed_seconds=0,
            running_since=None,
            version=expected_version + 1,
            updated_at=now,
        )
    )

    if result.rowcount != 1:
        await db.rollback()
        raise ClockConflictError(
            "Clock changed before reset; refetch current state"
        )

    await db.commit()
    clock = await _reload_clock(db, game_id)

    await _emit_clock_updated(clock, "reset")

    return clock
