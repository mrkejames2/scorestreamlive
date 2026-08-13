"""Player service layer."""

import uuid
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.player import Player
from app.models.team import Team
from app.schemas.player import PlayerCreate, PlayerUpdate
from app.sockets import sio


def _serialize_player(player: Player) -> dict:
    """Serialize a Player to a JSON-safe dict for Socket.IO."""
    return {
        "id": str(player.id),
        "team_id": str(player.team_id),
        "first_name": player.first_name,
        "last_name": player.last_name,
        "jersey_number": player.jersey_number,
        "created_at": player.created_at.isoformat(),
        "updated_at": player.updated_at.isoformat(),
    }


async def _validate_player_create(
    db: AsyncSession,
    data: PlayerCreate,
) -> None:
    """Validate Player creation data."""
    team = await db.get(Team, data.team_id)
    if not team:
        raise ValueError("Team not found")

    first = data.first_name.strip() if data.first_name else ""
    last = data.last_name.strip() if data.last_name else ""
    if not first:
        raise ValueError("first_name is required")
    if not last:
        raise ValueError("last_name is required")


async def create_player(db: AsyncSession, data: PlayerCreate) -> Player:
    """Create and persist a new Player, then broadcast via Socket.IO."""
    await _validate_player_create(db, data)

    now = datetime.now(timezone.utc)
    player = Player(
        team_id=data.team_id,
        first_name=data.first_name.strip(),
        last_name=data.last_name.strip(),
        jersey_number=data.jersey_number,
        created_at=now,
        updated_at=now,
    )
    db.add(player)
    await db.commit()
    await db.refresh(player)

    await sio.emit("player:created", _serialize_player(player))
    await sio.emit("roster:updated", {"team_id": str(player.team_id)})
    return player


async def get_player(db: AsyncSession, player_id: uuid.UUID) -> Optional[Player]:
    """Return a single Player by ID, or None if not found."""
    result = await db.execute(select(Player).where(Player.id == player_id))
    return result.scalar_one_or_none()


async def update_player(
    db: AsyncSession,
    player_id: uuid.UUID,
    data: PlayerUpdate,
) -> Optional[Player]:
    """Update an existing Player, then broadcast the change via Socket.IO."""
    result = await db.execute(select(Player).where(Player.id == player_id))
    player = result.scalar_one_or_none()
    if not player:
        return None

    if data.first_name is not None:
        stripped = data.first_name.strip()
        if not stripped:
            raise ValueError("first_name cannot be empty")
        player.first_name = stripped

    if data.last_name is not None:
        stripped = data.last_name.strip()
        if not stripped:
            raise ValueError("last_name cannot be empty")
        player.last_name = stripped

    if data.jersey_number is not None:
        player.jersey_number = data.jersey_number

    player.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(player)

    await sio.emit("player:updated", _serialize_player(player))
    await sio.emit("roster:updated", {"team_id": str(player.team_id)})
    return player


async def get_team_players(db: AsyncSession, team_id: uuid.UUID) -> List[Player]:
    """Return all Players for a Team in deterministic order."""
    result = await db.execute(
        select(Player)
        .where(Player.team_id == team_id)
        .order_by(
            Player.jersey_number.asc().nulls_last(),
            Player.last_name.asc(),
            Player.first_name.asc(),
            Player.id.asc(),
        )
    )
    return list(result.scalars().all())