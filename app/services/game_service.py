"""Game service layer with M15-C Club scoping."""

import uuid
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import func, select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.game import Game
from app.models.team import Team
from app.schemas.game import GameCreate, GameUpdate, GameOverlayTheme
from app.sockets import sio


def _serialize_game(game: Game) -> dict:
    """Serialize a Game to a JSON-safe dict for Socket.IO."""
    return {
        "id": str(game.id),
        "name": game.name,
        "sport": game.sport,
        "my_team_id": str(game.my_team_id) if game.my_team_id else None,
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
        "archived_at": game.archived_at.isoformat() if game.archived_at else None,
        "created_at": game.created_at.isoformat(),
        "updated_at": game.updated_at.isoformat(),
        "broadcast_message": game.broadcast_message,
        "overlay_theme": game.overlay_theme or "standard",
    }


async def _validate_game_teams(
    db: AsyncSession,
    club_id: uuid.UUID,
    home_team_id: Optional[uuid.UUID],
    away_team_id: Optional[uuid.UUID],
    sport: str = "soccer",
) -> None:
    """Validate Game Team references and enforce same-Club isolation."""
    if home_team_id and away_team_id and home_team_id == away_team_id:
        raise ValueError("Home and away teams must be different")

    if home_team_id:
        team = await db.get(Team, home_team_id)
        if not team or team.club_id != club_id or team.archived_at is not None or team.sport != sport:
            raise ValueError("Home team not found")

    if away_team_id:
        team = await db.get(Team, away_team_id)
        if not team or team.club_id != club_id or team.archived_at is not None or team.sport != sport:
            raise ValueError("Away team not found")


async def create_game(
    db: AsyncSession,
    data: GameCreate,
    club_id: uuid.UUID,
) -> Game:
    """Create and persist a Club-scoped Game, then broadcast committed state."""
    await _validate_game_teams(db, club_id, data.home_team_id, data.away_team_id, data.sport)

    # M21-F R4: My Team is a participant, not a separate opponent roster.
    if data.sport == "futsal":
        if data.my_team_id is None or data.my_team_id not in (data.home_team_id, data.away_team_id):
            raise ValueError("Select My Team as Home or Away for Futsal")
    elif data.my_team_id is not None:
        raise ValueError("My Team selection is only supported for Futsal")

    now = datetime.now(timezone.utc)
    game = Game(
        club_id=club_id,
        sport=data.sport,
        my_team_id=data.my_team_id if data.sport == "futsal" else None,
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

    result = await db.execute(
        select(Game)
        .options(selectinload(Game.home_team), selectinload(Game.away_team))
        .where(Game.id == game.id)
    )
    game = result.scalar_one()

    # M15-C repair: preserve the accepted post-commit creation event.
    await sio.emit("game:created", _serialize_game(game))
    return game


async def list_games(
    db: AsyncSession,
    limit: Optional[int] = None,
    club_id: Optional[uuid.UUID] = None,
    archived: bool = False,
) -> List[Game]:
    """Return Games in deterministic dashboard-recency order, optionally Club-scoped."""
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
    )

    if club_id is not None:
        query = query.where(Game.club_id == club_id)

    query = query.where(Game.archived_at.is_not(None) if archived else Game.archived_at.is_(None))

    query = query.order_by(
        recency.desc(),
        Game.id.desc(),
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


async def update_game(
    db: AsyncSession,
    game_id: uuid.UUID,
    data: GameUpdate,
) -> Optional[Game]:
    """Update an existing Game, then broadcast committed state."""
    result = await db.execute(
        select(Game)
        .options(selectinload(Game.home_team), selectinload(Game.away_team))
        .where(Game.id == game_id)
    )
    game = result.scalar_one_or_none()
    if not game:
        return None

    final_home = data.home_team_id if data.home_team_id is not None else game.home_team_id
    final_away = data.away_team_id if data.away_team_id is not None else game.away_team_id
    await _validate_game_teams(db, game.club_id, final_home, final_away, game.sport)
    # Preserve explicit selection when editing participants; allow assigning
    # My Team to older Futsal games that predate this revision.
    final_my_team = data.my_team_id if data.my_team_id is not None else game.my_team_id
    if game.sport == "futsal":
        if final_my_team is not None and final_my_team not in (final_home, final_away):
            raise ValueError("My Team must be Home or Away in this Futsal game")
    elif data.my_team_id is not None:
        raise ValueError("My Team selection is only supported for Futsal")

    if data.my_team_id is not None and game.sport == "futsal":
        game.my_team_id = data.my_team_id
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

async def update_overlay_theme(db: AsyncSession, game_id: uuid.UUID, overlay_theme: GameOverlayTheme) -> Optional[Game]:
    result = await db.execute(select(Game).options(selectinload(Game.home_team),selectinload(Game.away_team)).where(Game.id == game_id))
    game = result.scalar_one_or_none()
    if not game: return None
    game.overlay_theme = overlay_theme.value
    game.updated_at = datetime.now(timezone.utc)
    await db.commit()
    result = await db.execute(select(Game).options(selectinload(Game.home_team),selectinload(Game.away_team)).where(Game.id == game.id))
    game = result.scalar_one()
    await sio.emit("game:updated", _serialize_game(game))
    return game
