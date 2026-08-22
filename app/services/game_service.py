"""Game service layer."""

import uuid
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import func, select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.game import Game
from app.models.team import Team
from app.schemas.game import GameCreate, GameUpdate
from app.sockets import sio


def _serialize_game(game: Game) -> dict:
    """Serialize a Game to a JSON-safe dict for Socket.IO."""
    return {
        "id": str(game.id),
        "name": game.name,
        "status": game.status,
        "scheduled_at": game.scheduled_at.isoformat() if game.scheduled_at else None,
        "home_team_id": str(game.home_team_id) if game.home_team_id else None,
        "away_team_id": str(game.away_team_id) if game.away_team_id else None,
        "home_team": {
            "id": str(game.home_team.id),
            "name": game.home_team.name,
            "short_name": game.home_team.short_name,
        } if game.home_team else None,
        "away_team": {
            "id": str(game.away_team.id),
            "name": game.away_team.name,
            "short_name": game.away_team.short_name,
        } if game.away_team else None,
        "created_at": game.created_at.isoformat(),
        "updated_at": game.updated_at.isoformat(),
        "broadcast_message": game.broadcast_message,
    }


async def _validate_game_teams(
    db: AsyncSession,
    home_team_id: Optional[uuid.UUID],
    away_team_id: Optional[uuid.UUID],
) -> None:
    """Validate team references for a Game."""
    if home_team_id and away_team_id and home_team_id == away_team_id:
        raise ValueError("Home and away teams must be different")

    if home_team_id:
        team = await db.get(Team, home_team_id)
        if not team:
            raise ValueError("Home team not found")

    if away_team_id:
        team = await db.get(Team, away_team_id)
        if not team:
            raise ValueError("Away team not found")


async def create_game(db: AsyncSession, data: GameCreate) -> Game:
    """Create and persist a new Game, then broadcast via Socket.IO."""
    await _validate_game_teams(db, data.home_team_id, data.away_team_id)

    now = datetime.now(timezone.utc)
    game = Game(
        name=data.name,
        status=data.status.value,
        scheduled_at=data.scheduled_at,
        home_team_id=data.home_team_id,
        away_team_id=data.away_team_id,
        created_at=now,
        updated_at=now,
    )
    db.add(game)
    await db.commit()

    # Re-query with relationships loaded for serialization
    result = await db.execute(
        select(Game)
        .options(selectinload(Game.home_team), selectinload(Game.away_team))
        .where(Game.id == game.id)
    )
    game = result.scalar_one()

    await sio.emit("game:created", _serialize_game(game))
    return game


async def list_games(
    db: AsyncSession,
    limit: Optional[int] = None,
) -> List[Game]:
    """Return Games in deterministic dashboard-recency order."""
    recency = func.coalesce(
        Game.scheduled_at,
        Game.updated_at,
        Game.created_at,
    )

    query = (
        select(Game)
        .options(
            selectinload(Game.home_team),
            selectinload(Game.away_team),
        )
        .order_by(
            recency.desc(),
            Game.id.desc(),
        )
    )

    if limit is not None:
        query = query.limit(limit)

    result = await db.execute(query)
    return list(result.scalars().all())


async def get_game(db: AsyncSession, game_id: uuid.UUID) -> Optional[Game]:
    """Return a single Game by ID, or None if not found."""
    result = await db.execute(
        select(Game)
        .options(selectinload(Game.home_team), selectinload(Game.away_team))
        .where(Game.id == game_id)
    )
    return result.scalar_one_or_none()


async def update_game(db: AsyncSession, game_id: uuid.UUID, data: GameUpdate) -> Optional[Game]:
    """Update an existing Game, then broadcast the change via Socket.IO."""
    result = await db.execute(
        select(Game)
        .options(selectinload(Game.home_team), selectinload(Game.away_team))
        .where(Game.id == game_id)
    )
    game = result.scalar_one_or_none()
    if not game:
        return None

    # Determine final team IDs for validation
    final_home = data.home_team_id if data.home_team_id is not None else game.home_team_id
    final_away = data.away_team_id if data.away_team_id is not None else game.away_team_id
    await _validate_game_teams(db, final_home, final_away)

    if data.name is not None:
        game.name = data.name
    if data.status is not None:
        game.status = data.status.value
    if data.scheduled_at is not None:
        game.scheduled_at = data.scheduled_at
    if data.home_team_id is not None:
        game.home_team_id = data.home_team_id
    if data.away_team_id is not None:
        game.away_team_id = data.away_team_id

    game.updated_at = datetime.now(timezone.utc)
    await db.commit()

    # Re-query with fresh relationships
    result = await db.execute(
        select(Game)
        .options(selectinload(Game.home_team), selectinload(Game.away_team))
        .where(Game.id == game.id)
    )
    game = result.scalar_one()

    await sio.emit("game:updated", _serialize_game(game))
    return game

async def update_broadcast_message(
    db: AsyncSession,
    game_id: uuid.UUID,
    message: Optional[str],
) -> Optional[Game]:
    """Persist broadcast message and emit committed Game state."""
    result = await db.execute(
        select(Game)
        .options(selectinload(Game.home_team), selectinload(Game.away_team))
        .where(Game.id == game_id)
    )
    game = result.scalar_one_or_none()
    if not game:
        return None

    normalized = (message or "").strip()
    game.broadcast_message = normalized or None
    game.updated_at = datetime.now(timezone.utc)
    await db.commit()

    result = await db.execute(
        select(Game)
        .options(selectinload(Game.home_team), selectinload(Game.away_team))
        .where(Game.id == game.id)
    )
    game = result.scalar_one()
    await sio.emit("game:updated", _serialize_game(game))
    return game
