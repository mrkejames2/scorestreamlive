"""Server-side authorization and role visibility rules for M15-D."""

import uuid
from typing import Optional, Set

from fastapi import HTTPException, status
from sqlalchemy import exists, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.roles import ClubRole
from app.models.game import Game
from app.models.game_operator import GameOperator
from app.models.team import Team
from app.models.user import User


def _same_club(user: User, club_id: uuid.UUID | None) -> bool:
    return (
        user.club_id is not None
        and club_id is not None
        and user.club_id == club_id
    )


def require_director(user: User) -> None:
    if user.club_id is None or user.club_role != ClubRole.DIRECTOR.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Director access required",
        )


async def visible_team_ids(
    db: AsyncSession,
    user: User,
) -> Optional[Set[uuid.UUID]]:
    """Return None for Director, otherwise explicit visible Team IDs."""
    if user.club_id is None:
        return set()

    if user.club_role in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }:
        return None

    if user.club_role == ClubRole.OPERATOR.value:
        result = await db.execute(
            select(Game.home_team_id, Game.away_team_id)
            .join(GameOperator, GameOperator.game_id == Game.id)
            .where(
                GameOperator.user_id == user.id,
                Game.club_id == user.club_id,
            )
        )

        team_ids: Set[uuid.UUID] = set()
        for home_team_id, away_team_id in result.all():
            if home_team_id is not None:
                team_ids.add(home_team_id)
            if away_team_id is not None:
                team_ids.add(away_team_id)
        return team_ids

    return set()


async def visible_game_ids(
    db: AsyncSession,
    user: User,
) -> Optional[Set[uuid.UUID]]:
    """Return None for Director, otherwise explicit visible Game IDs."""
    if user.club_id is None:
        return set()

    if user.club_role in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }:
        return None

    if user.club_role == ClubRole.OPERATOR.value:
        result = await db.execute(
            select(GameOperator.game_id)
            .join(Game, Game.id == GameOperator.game_id)
            .where(
                GameOperator.user_id == user.id,
                Game.club_id == user.club_id,
            )
        )
        return set(result.scalars().all())

    return set()


async def can_view_team(
    db: AsyncSession,
    user: User,
    team: Team,
) -> bool:
    if not _same_club(user, team.club_id):
        return False

    visible = await visible_team_ids(db, user)
    return visible is None or team.id in visible


async def can_view_game(
    db: AsyncSession,
    user: User,
    game: Game,
) -> bool:
    if not _same_club(user, game.club_id):
        return False

    visible = await visible_game_ids(db, user)
    return visible is None or game.id in visible


async def can_create_game_with_teams(
    db: AsyncSession,
    user: User,
    home_team_id: uuid.UUID | None,
    away_team_id: uuid.UUID | None,
) -> bool:
    """Validate that the creator may use both Teams in a new Game."""
    if user.club_id is None:
        return False

    if user.club_role not in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }:
        return False

    for team_id in (home_team_id, away_team_id):
        if team_id is None:
            continue
        team = await db.get(Team, team_id)
        if not team or team.club_id != user.club_id:
            return False

    return True


async def can_manage_team(
    db: AsyncSession,
    user: User,
    team: Team,
) -> bool:
    if not _same_club(user, team.club_id):
        return False

    return user.club_role in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }


async def can_operate_game(
    db: AsyncSession,
    user: User,
    game: Game,
) -> bool:
    if not _same_club(user, game.club_id):
        return False

    if user.club_role in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }:
        return True

    if user.club_role == ClubRole.OPERATOR.value:
        result = await db.execute(
            select(
                exists().where(
                    GameOperator.game_id == game.id,
                    GameOperator.user_id == user.id,
                )
            )
        )
        return bool(result.scalar())

    return False


def deny_not_found(resource: str) -> None:
    """Avoid leaking cross-Club resource existence."""
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"{resource} not found",
    )
