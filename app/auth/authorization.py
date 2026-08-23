"""Server-side M15-C authorization rules."""

import uuid

from fastapi import HTTPException, status
from sqlalchemy import exists, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.roles import ClubRole
from app.models.game import Game
from app.models.game_operator import GameOperator
from app.models.team import Team
from app.models.team_manager import TeamManager
from app.models.user import User


def _same_club(user: User, club_id: uuid.UUID | None) -> bool:
    return user.club_id is not None and club_id is not None and user.club_id == club_id


async def can_manage_team(db: AsyncSession, user: User, team: Team) -> bool:
    if not _same_club(user, team.club_id):
        return False
    if user.club_role == ClubRole.DIRECTOR.value:
        return True
    if user.club_role != ClubRole.MANAGER.value:
        return False
    result = await db.execute(
        select(exists().where(
            TeamManager.team_id == team.id,
            TeamManager.user_id == user.id,
        ))
    )
    return bool(result.scalar())


async def can_operate_game(db: AsyncSession, user: User, game: Game) -> bool:
    if not _same_club(user, game.club_id):
        return False
    if user.club_role == ClubRole.DIRECTOR.value:
        return True

    if user.club_role == ClubRole.OPERATOR.value:
        result = await db.execute(
            select(exists().where(
                GameOperator.game_id == game.id,
                GameOperator.user_id == user.id,
            ))
        )
        return bool(result.scalar())

    if user.club_role == ClubRole.MANAGER.value:
        team_ids = [x for x in (game.home_team_id, game.away_team_id) if x is not None]
        if not team_ids:
            return False
        result = await db.execute(
            select(exists().where(
                TeamManager.user_id == user.id,
                TeamManager.team_id.in_(team_ids),
            ))
        )
        return bool(result.scalar())

    return False


def deny_not_found(resource: str) -> None:
    """Avoid leaking cross-club resource existence."""
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"{resource} not found",
    )
