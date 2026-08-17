"""Scoring service layer."""

import uuid
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import select, update
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


async def create_scoring_event(
    db: AsyncSession, data: ScoringEventCreate
) -> ScoringEvent:
    """Create a scoring event and atomically increment the Game score."""
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
    #
    # Scoring existed before the clock domain, so absence of a clock remains
    # valid for backwards compatibility. For M8/M9/M10 games, exactly one
    # clock exists because game_clocks.game_id is unique.
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

    # 6. Create ScoringEvent.
    #
    # game_elapsed_seconds is server-computed. It is never accepted from the
    # browser, and created_at remains available as audit/debug metadata.
    scoring_event = ScoringEvent(
        game_id=data.game_id,
        team_id=data.team_id,
        player_id=data.player_id,
        event_type=data.event_type,
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

    # 8. Single commit: scoring event + score increment remain one transaction.
    await db.commit()

    # 9. Refresh committed state
    await db.refresh(scoring_event)
    await db.refresh(game)

    # 10. Emit Socket.IO domain events
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