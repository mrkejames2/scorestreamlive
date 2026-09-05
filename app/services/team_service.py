"""Team service layer with M15-C Club scoping."""

import uuid
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.team import Team
from app.schemas.team import TeamCreate, TeamUpdate
from app.sockets import sio


def _serialize_team(team: Team) -> dict:
    """Serialize a Team to a JSON-safe dict for Socket.IO."""
    return {
        "id": str(team.id),
        "name": team.name,
        "short_name": team.short_name,
        "logo_url": team.logo_url,
        "primary_color": team.primary_color,
        "secondary_color": team.secondary_color,
        "archived_at": team.archived_at.isoformat() if team.archived_at else None,
        "created_at": team.created_at.isoformat(),
        "updated_at": team.updated_at.isoformat(),
    }


async def create_team(
    db: AsyncSession,
    data: TeamCreate,
    club_id: uuid.UUID,
) -> Team:
    """Create and persist a Club-scoped Team, then broadcast committed state."""
    now = datetime.now(timezone.utc)
    team = Team(
        club_id=club_id,
        name=data.name,
        short_name=data.short_name,
        logo_url=data.logo_url,
        primary_color=data.primary_color,
        secondary_color=data.secondary_color,
        created_at=now,
        updated_at=now,
    )
    db.add(team)
    await db.commit()
    await db.refresh(team)

    await sio.emit("team:created", _serialize_team(team))
    return team


async def list_teams(
    db: AsyncSession,
    club_id: uuid.UUID,
    archived: bool = False,
) -> List[Team]:
    """Return Teams for one Club ordered newest first."""
    result = await db.execute(
        select(Team)
        .where(Team.club_id == club_id)
        .where(Team.archived_at.is_not(None) if archived else Team.archived_at.is_(None))
        .order_by(Team.created_at.desc())
    )
    return list(result.scalars().all())


async def get_team(db: AsyncSession, team_id: uuid.UUID) -> Optional[Team]:
    """Return a single Team by ID, or None if not found."""
    result = await db.execute(select(Team).where(Team.id == team_id))
    return result.scalar_one_or_none()


async def update_team(
    db: AsyncSession,
    team_id: uuid.UUID,
    data: TeamUpdate,
) -> Optional[Team]:
    """Update an existing Team, then broadcast committed state."""
    result = await db.execute(select(Team).where(Team.id == team_id))
    team = result.scalar_one_or_none()
    if not team:
        return None
    if team.archived_at is not None:
        raise ValueError("Archived Teams are read-only")

    if data.name is not None:
        team.name = data.name
    if data.short_name is not None:
        team.short_name = data.short_name
    if data.logo_url is not None:
        team.logo_url = data.logo_url
    if data.primary_color is not None:
        team.primary_color = data.primary_color
    if data.secondary_color is not None:
        team.secondary_color = data.secondary_color

    team.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(team)

    await sio.emit("team:updated", _serialize_team(team))
    return team


async def set_team_logo_url(
    db: AsyncSession,
    team_id: uuid.UUID,
    logo_url: str,
) -> Optional[Team]:
    """Persist a Team logo URL and emit the committed Team state."""
    result = await db.execute(select(Team).where(Team.id == team_id))
    team = result.scalar_one_or_none()

    if not team:
        return None
    if team.archived_at is not None:
        raise ValueError("Archived Teams are read-only")

    team.logo_url = logo_url
    team.updated_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(team)

    await sio.emit("team:updated", _serialize_team(team))
    return team
