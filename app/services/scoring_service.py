"""Scoring service layer."""

import uuid
from datetime import datetime, timezone
from typing import List

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.game import Game
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
        "created_at": event.created_at.isoformat(),
    }


def _serialize_game_score(game: Game) -> dict:
    """Serialize Game score state for Socket.IO emission."""
    return {
        "game_id": str(game.id),
        "home_score": game.home_score,
        "away_score": game.away_score,
    }


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

    # 4. Create ScoringEvent
    now = datetime.now(timezone.utc)
    scoring_event = ScoringEvent(
        game_id=data.game_id,
        team_id=data.team_id,
        player_id=data.player_id,
        event_type=data.event_type,
        created_at=now,
    )
    db.add(scoring_event)

    # 5. Atomic score increment
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

    # 6. Single commit
    await db.commit()

    # 7. Refresh committed state
    await db.refresh(scoring_event)
    await db.refresh(game)

    # 8. Emit Socket.IO domain events
    sio.emit("scoring_event:created", _serialize_scoring_event(scoring_event))
    sio.emit("game:score_updated", _serialize_game_score(game))

    return scoring_event


async def get_game_scoring_events(
    db: AsyncSession, game_id: uuid.UUID
) -> List[ScoringEvent]:
    """Return all ScoringEvents for a Game in deterministic order."""
    result = await db.execute(
        select(ScoringEvent)
        .where(ScoringEvent.game_id == game_id)
        .order_by(ScoringEvent.created_at.asc(), ScoringEvent.id.asc())
    )
    return list(result.scalars().all())