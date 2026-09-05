"""M17-B safe Team/Game archive, restore, and hard-delete policy."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.game import Game
from app.models.game_clock import GameClock
from app.models.game_lifecycle import GameLifecycle
from app.models.game_operator import GameOperator
from app.models.player import Player
from app.models.scoring_event import ScoringEvent
from app.models.team import Team
from app.models.team_manager import TeamManager


class LifecycleConflict(ValueError):
    """The resource has durable history and must be archived instead of deleted."""


async def archive_team(db: AsyncSession, team: Team) -> Team:
    if team.archived_at is None:
        now = datetime.now(timezone.utc)
        team.archived_at = now
        team.updated_at = now
        await db.commit()
        await db.refresh(team)
    return team


async def restore_team(db: AsyncSession, team: Team) -> Team:
    if team.archived_at is not None:
        team.archived_at = None
        team.updated_at = datetime.now(timezone.utc)
        await db.commit()
        await db.refresh(team)
    return team


async def archive_game(db: AsyncSession, game: Game) -> Game:
    if game.archived_at is None:
        now = datetime.now(timezone.utc)
        game.archived_at = now
        game.updated_at = now
        await db.commit()
        await db.refresh(game)
    return game


async def restore_game(db: AsyncSession, game: Game) -> Game:
    if game.archived_at is not None:
        game.archived_at = None
        game.updated_at = datetime.now(timezone.utc)
        await db.commit()
        await db.refresh(game)
    return game


async def _count(db: AsyncSession, model, *criteria) -> int:
    result = await db.execute(select(func.count()).select_from(model).where(*criteria))
    return int(result.scalar_one())


async def hard_delete_game(db: AsyncSession, game: Game) -> None:
    """Delete only a pristine Game. Administrative operator assignments are disposable."""
    blockers = []
    if await _count(db, ScoringEvent, ScoringEvent.game_id == game.id):
        blockers.append("scoring events")
    if await _count(db, GameClock, GameClock.game_id == game.id):
        blockers.append("clock state")
    if await _count(db, GameLifecycle, GameLifecycle.game_id == game.id):
        blockers.append("match lifecycle state")
    if game.home_score or game.away_score:
        blockers.append("score state")
    if game.status != "scheduled":
        blockers.append("game status")

    if blockers:
        raise LifecycleConflict(
            "This game contains match history and cannot be permanently deleted. "
            "Archive it instead."
        )

    await db.execute(delete(GameOperator).where(GameOperator.game_id == game.id))
    await db.delete(game)
    await db.commit()


async def hard_delete_team(db: AsyncSession, team: Team) -> None:
    """Delete only an unused Team. Administrative manager assignments are disposable."""
    blockers = []
    if await _count(db, Player, Player.team_id == team.id):
        blockers.append("players")
    if await _count(
        db,
        Game,
        or_(Game.home_team_id == team.id, Game.away_team_id == team.id),
    ):
        blockers.append("games")
    if await _count(db, ScoringEvent, ScoringEvent.team_id == team.id):
        blockers.append("scoring history")

    if blockers:
        raise LifecycleConflict(
            "This team contains roster or game history and cannot be permanently deleted. "
            "Archive it instead."
        )

    await db.execute(delete(TeamManager).where(TeamManager.team_id == team.id))
    await db.delete(team)
    await db.commit()
