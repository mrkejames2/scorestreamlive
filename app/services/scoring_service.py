"""Scoring service layer."""

import uuid
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.game import Game
from app.models.game_clock import GameClock
from app.models.player import Player
from app.models.scoring_event import ScoringEvent
from app.schemas.scoring_event import ScoringEventCreate
from app.sockets import sio


def _serialize_scoring_event(event: ScoringEvent) -> dict:
    """Serialize a ScoringEvent for Socket.IO emission."""
    return {
        "id": str(event.id),
        "game_id": str(event.game_id),
        "team_id": str(event.team_id),
        "player_id": str(event.player_id) if event.player_id else None,
        "event_type": event.event_type,
        "request_id": str(event.request_id) if event.request_id else None,
        "game_elapsed_seconds": event.game_elapsed_seconds,
        "created_at": event.created_at.isoformat(),
    }


def _serialize_game_score(game: Game) -> dict:
    """Serialize Game score state for Socket.IO emission."""
    return {
        "game_id": str(game.id),
        "home_score": game.home_score,
        "away_score": game.away_score,
    }


def _authoritative_elapsed_seconds(
    clock: Optional[GameClock],
    now: datetime,
) -> Optional[int]:
    """Return the authoritative M8 elapsed-time snapshot for a scoring event.

    A GameClock is optional because the scoring domain predates M8 and older
    regression tests/games may legitimately record a goal without a clock.

    When the clock is not running, the persisted accumulated elapsed_seconds
    value is authoritative.

    When running, M8 defines authoritative elapsed time as:

        elapsed_seconds + floor(now - running_since)

    No clock state is mutated here and no per-second writes are introduced.
    """
    if clock is None:
        return None

    elapsed = int(clock.elapsed_seconds)

    if clock.status == "running" and clock.running_since is not None:
        delta_seconds = int(
            (now - clock.running_since).total_seconds()
        )
        elapsed += max(0, delta_seconds)

    return max(0, elapsed)


def _same_scoring_command(
    event: ScoringEvent,
    data: ScoringEventCreate,
) -> bool:
    """Return True only when an idempotency replay matches the original."""
    return (
        event.game_id == data.game_id
        and event.team_id == data.team_id
        and event.player_id == data.player_id
        and event.event_type == data.event_type
    )


async def _existing_request(
    db: AsyncSession,
    request_id: Optional[uuid.UUID],
) -> Optional[ScoringEvent]:
    if request_id is None:
        return None

    result = await db.execute(
        select(ScoringEvent).where(
            ScoringEvent.request_id == request_id
        )
    )
    return result.scalar_one_or_none()


def _validate_idempotent_replay(
    event: ScoringEvent,
    data: ScoringEventCreate,
) -> None:
    if not _same_scoring_command(event, data):
        raise ValueError(
            "request_id was already used for a different scoring command"
        )


async def create_scoring_event(
    db: AsyncSession, data: ScoringEventCreate
) -> ScoringEvent:
    """Create one goal transaction, idempotent when request_id is supplied."""

    # M16-A fast replay path. This is intentionally server-side: browser
    # button disabling alone is not the authority for duplicate protection.
    existing = await _existing_request(db, data.request_id)
    if existing is not None:
        _validate_idempotent_replay(existing, data)
        return existing

    # 1. Validate Game exists
    game = await db.get(Game, data.game_id)
    if not game:
        raise ValueError("Game not found")

    # 2. Validate Team belongs to Game
    if data.team_id not in (game.home_team_id, game.away_team_id):
        raise ValueError("Team does not participate in this Game")

    # 3. Validate Player if supplied
    if data.player_id is not None:
        player = await db.get(Player, data.player_id)
        if not player:
            raise ValueError("Player not found")
        if player.team_id != data.team_id:
            raise ValueError("Player does not belong to the scoring Team")

    # 4. Read the persisted GameClock, if this Game has one.
    clock_result = await db.execute(
        select(GameClock).where(GameClock.game_id == data.game_id)
    )
    clock = clock_result.scalar_one_or_none()

    # 5. Capture one authoritative server timestamp and derive the durable
    # match-time snapshot from the M8 anchor-based clock.
    now = datetime.now(timezone.utc)
    game_elapsed_seconds = _authoritative_elapsed_seconds(
        clock,
        now,
    )

    # 6. Create ScoringEvent. request_id is caller-generated but is only a
    # command identity; score, event time, and all domain validation remain
    # server authoritative.
    scoring_event = ScoringEvent(
        game_id=data.game_id,
        team_id=data.team_id,
        player_id=data.player_id,
        event_type=data.event_type,
        request_id=data.request_id,
        game_elapsed_seconds=game_elapsed_seconds,
        created_at=now,
    )
    db.add(scoring_event)

    # 7. Atomic score increment
    if data.team_id == game.home_team_id:
        await db.execute(
            update(Game)
            .where(Game.id == data.game_id)
            .values(home_score=Game.home_score + 1)
        )
    else:
        await db.execute(
            update(Game)
            .where(Game.id == data.game_id)
            .values(away_score=Game.away_score + 1)
        )

    # 8. Single commit. The unique request_id index closes the concurrent
    # replay race. If another request with the same identity committed first,
    # this entire transaction (including score increment) rolls back.
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()

        if data.request_id is None:
            raise

        existing = await _existing_request(db, data.request_id)
        if existing is None:
            raise

        _validate_idempotent_replay(existing, data)
        return existing

    # 9. Refresh committed state
    await db.refresh(scoring_event)
    await db.refresh(game)

    # 10. Emit Socket.IO domain events only for the newly committed command.
    # An idempotent replay returns above and does not emit a duplicate goal.
    await sio.emit(
        "scoring_event:created",
        _serialize_scoring_event(scoring_event),
    )
    await sio.emit(
        "game:score_updated",
        _serialize_game_score(game),
    )

    return scoring_event


async def get_game_scoring_events(
    db: AsyncSession, game_id: uuid.UUID
) -> List[ScoringEvent]:
    """Return all ScoringEvents for a Game in deterministic order."""
    result = await db.execute(
        select(ScoringEvent)
        .where(ScoringEvent.game_id == game_id)
        .order_by(
            ScoringEvent.created_at.asc(),
            ScoringEvent.id.asc(),
        )
    )
    return list(result.scalars().all())


def _player_display_name(player: Optional[Player]) -> str:
    if player is None:
        return "Unknown scorer"
    parts = [player.first_name, player.last_name]
    return " ".join(part for part in parts if part).strip() or "Unknown scorer"


async def update_scoring_event_scorer(
    db: AsyncSession,
    event_id: uuid.UUID,
    player_id: Optional[uuid.UUID],
) -> ScoringEvent:
    event = await db.get(ScoringEvent, event_id)
    if not event:
        raise ValueError("Scoring event not found")

    # M16-D: an identical correction is a true no-op. Do not commit and do
    # not emit correction events for a command that changes no authoritative
    # data.
    if event.player_id == player_id:
        return event

    previous_player = await db.get(Player, event.player_id) if event.player_id else None
    player = None
    if player_id is not None:
        player = await db.get(Player, player_id)
        if not player:
            raise ValueError("Player not found")
        if player.team_id != event.team_id:
            raise ValueError("Player does not belong to the scoring Team")
    event.player_id = player_id
    await db.commit()
    await db.refresh(event)
    corrected_name = _player_display_name(player)
    if previous_player is None and player is not None:
        message = f"{corrected_name} scored."
    elif player is None:
        message = "Goal credited to Unknown scorer."
    else:
        message = f"Goal credited to {corrected_name}."
    await sio.emit("scoring_event:updated", _serialize_scoring_event(event))
    await sio.emit(
        "scoring_event:corrected",
        {
            **_serialize_scoring_event(event),
            "correction_type": "scorer_changed",
            "message": message,
        },
    )
    return event


async def delete_scoring_event(db: AsyncSession, event_id: uuid.UUID) -> None:
    event = await db.get(ScoringEvent, event_id)
    if not event:
        raise ValueError("Scoring event not found")
    game = await db.get(Game, event.game_id)
    if not game:
        raise ValueError("Game not found")
    payload = _serialize_scoring_event(event)
    if event.team_id == game.home_team_id:
        game.home_score = max(0, int(game.home_score) - 1)
    elif event.team_id == game.away_team_id:
        game.away_score = max(0, int(game.away_score) - 1)
    else:
        raise ValueError("Scoring event Team does not participate in this Game")
    await db.delete(event)
    await db.commit()
    await db.refresh(game)
    await sio.emit(
        "scoring_event:deleted",
        {**payload, "correction_type": "goal_removed"},
    )
    await sio.emit("game:score_updated", _serialize_game_score(game))
    await sio.emit(
        "scoring_event:corrected",
        {
            **payload,
            "correction_type": "goal_removed",
            "message": "Goal removed.",
        },
    )
