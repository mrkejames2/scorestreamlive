"""Game service layer."""

import uuid
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.game import Game
from app.schemas.game import GameCreate, GameUpdate
from app.sockets import sio


def _serialize_game(game: Game) -> dict:
    """Serialize a Game to a JSON-safe dict for Socket.IO."""
    return {
        "id": str(game.id),
        "name": game.name,
        "status": game.status,
        "scheduled_at": game.scheduled_at.isoformat() if game.scheduled_at else None,
        "created_at": game.created_at.isoformat(),
        "updated_at": game.updated_at.isoformat(),
    }


async def create_game(db: AsyncSession, data: GameCreate) -> Game:
    """Create and persist a new Game, then broadcast via Socket.IO."""
    now = datetime.now(timezone.utc)
    game = Game(
        name=data.name,
        status=data.status.value,
        scheduled_at=data.scheduled_at,
        created_at=now,
        updated_at=now,
    )
    db.add(game)
    await db.commit()
    await db.refresh(game)

    await sio.emit("game:created", _serialize_game(game))
    return game


async def list_games(db: AsyncSession) -> List[Game]:
    """Return all Games ordered by creation time (newest first)."""
    result = await db.execute(select(Game).order_by(Game.created_at.desc()))
    return list(result.scalars().all())


async def get_game(db: AsyncSession, game_id: uuid.UUID) -> Optional[Game]:
    """Return a single Game by ID, or None if not found."""
    result = await db.execute(select(Game).where(Game.id == game_id))
    return result.scalar_one_or_none()


async def update_game(db: AsyncSession, game_id: uuid.UUID, data: GameUpdate) -> Optional[Game]:
    """Update an existing Game, then broadcast the change via Socket.IO."""
    result = await db.execute(select(Game).where(Game.id == game_id))
    game = result.scalar_one_or_none()
    if not game:
        return None

    if data.name is not None:
        game.name = data.name
    if data.status is not None:
        game.status = data.status.value
    if data.scheduled_at is not None:
        game.scheduled_at = data.scheduled_at

    game.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(game)

    await sio.emit("game:updated", _serialize_game(game))
    return game