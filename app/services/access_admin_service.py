"""Director member and assignment services."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.roles import ClubRole
from app.models.game import Game
from app.models.game_operator import GameOperator
from app.models.team import Team
from app.models.team_manager import TeamManager
from app.models.user import User
from app.models.user_session import UserSession
from app.services.auth_service import get_user_by_email, hash_password, normalize_email
from app.services.password_recovery_service import revoke_outstanding_password_resets


class AccessAdminNotFound(ValueError):
    """Requested Club administration resource is unavailable to this tenant."""


class AccessAdminConflict(ValueError):
    """Requested mutation would violate a Club administration invariant."""


async def list_club_members(db: AsyncSession, club_id: uuid.UUID):
    result = await db.execute(
        select(User)
        .where(User.club_id == club_id)
        .order_by(User.display_name.asc().nulls_last(), User.email.asc())
    )
    return list(result.scalars().all())


async def get_club_member(
    db: AsyncSession,
    club_id: uuid.UUID,
    user_id: uuid.UUID,
) -> User:
    result = await db.execute(
        select(User).where(User.id == user_id, User.club_id == club_id)
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise AccessAdminNotFound("Member not found")
    return user


async def member_assignments(
    db: AsyncSession,
    club_id: uuid.UUID,
    user_id: uuid.UUID,
) -> dict:
    user = await get_club_member(db, club_id, user_id)

    team_rows = await db.execute(
        select(TeamManager, Team)
        .join(Team, Team.id == TeamManager.team_id)
        .where(
            TeamManager.user_id == user.id,
            Team.club_id == club_id,
        )
        .order_by(Team.name.asc())
    )
    game_rows = await db.execute(
        select(GameOperator, Game)
        .join(Game, Game.id == GameOperator.game_id)
        .where(
            GameOperator.user_id == user.id,
            Game.club_id == club_id,
        )
        .order_by(Game.name.asc())
    )

    return {
        "team_managers": [
            {"team_id": str(team.id), "team_name": team.name}
            for _, team in team_rows.all()
        ],
        "game_operators": [
            {"game_id": str(game.id), "game_name": game.name}
            for _, game in game_rows.all()
        ],
    }


async def create_club_member(
    db: AsyncSession,
    club_id: uuid.UUID,
    email: str,
    display_name: str | None,
    role: ClubRole,
    password: str,
):
    email = normalize_email(email)
    if not email or "@" not in email:
        raise ValueError("Valid email is required")
    if len(password) < 8:
        raise ValueError("Temporary password must be at least 8 characters")
    if role not in {ClubRole.MANAGER, ClubRole.OPERATOR}:
        raise ValueError("New members must be Manager or Operator")
    if await get_user_by_email(db, email):
        raise ValueError("A user with that email already exists")

    now = datetime.now(timezone.utc)
    user = User(
        email=email,
        display_name=(display_name or "").strip() or None,
        password_hash=hash_password(password),
        is_active=True,
        club_id=club_id,
        club_role=role.value,
        created_at=now,
        updated_at=now,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def _lock_active_directors(
    db: AsyncSession,
    club_id: uuid.UUID,
) -> list[User]:
    """Serialize mutations that could remove an active Director."""
    result = await db.execute(
        select(User)
        .where(
            User.club_id == club_id,
            User.club_role == ClubRole.DIRECTOR.value,
            User.is_active.is_(True),
        )
        .order_by(User.id)
        .with_for_update()
    )
    return list(result.scalars().all())


async def update_club_member(
    db: AsyncSession,
    club_id: uuid.UUID,
    user_id: uuid.UUID,
    *,
    role: ClubRole | None = None,
    is_active: bool | None = None,
) -> User:
    """Update role/status while preserving tenant and Director invariants."""
    user = await get_club_member(db, club_id, user_id)

    requested_role = role.value if role is not None else user.club_role
    requested_active = is_active if is_active is not None else user.is_active

    removing_active_director = (
        user.club_role == ClubRole.DIRECTOR.value
        and user.is_active
        and (
            requested_role != ClubRole.DIRECTOR.value
            or requested_active is False
        )
    )

    if removing_active_director:
        directors = await _lock_active_directors(db, club_id)
        await db.refresh(user)

        # Another serialized transaction may have changed this user while we
        # waited for the Director locks. Re-evaluate against authoritative data.
        removing_active_director = (
            user.club_role == ClubRole.DIRECTOR.value
            and user.is_active
            and (
                requested_role != ClubRole.DIRECTOR.value
                or requested_active is False
            )
        )
        if removing_active_director and len(directors) <= 1:
            await db.rollback()
            raise AccessAdminConflict(
                "Club must retain at least one active Director"
            )

    role_changed = requested_role != user.club_role

    if role_changed:
        # Role and explicit assignments remain intentionally separate. Remove
        # assignments that would be incompatible with the new role so stale
        # access cannot silently reactivate after a later role change.
        if requested_role == ClubRole.MANAGER.value:
            await db.execute(
                delete(GameOperator).where(GameOperator.user_id == user.id)
            )
        elif requested_role == ClubRole.OPERATOR.value:
            await db.execute(
                delete(TeamManager).where(TeamManager.user_id == user.id)
            )
        elif requested_role == ClubRole.DIRECTOR.value:
            await db.execute(
                delete(TeamManager).where(TeamManager.user_id == user.id)
            )
            await db.execute(
                delete(GameOperator).where(GameOperator.user_id == user.id)
            )

        user.club_role = requested_role

    if is_active is not None and requested_active != user.is_active:
        user.is_active = requested_active
        if not requested_active:
            # Immediate server-side revocation. resolve_session_user() already
            # rejects inactive accounts; deleting sessions removes lingering
            # authenticated browser sessions at the source as well.
            await db.execute(
                delete(UserSession).where(UserSession.user_id == user.id)
            )
            await revoke_outstanding_password_resets(
                db,
                user.id,
                commit=False,
            )

    user.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(user)
    return user


async def assign_team_manager(
    db: AsyncSession,
    club_id: uuid.UUID,
    team_id: uuid.UUID,
    user_id: uuid.UUID,
):
    team = await db.get(Team, team_id)
    user = await db.get(User, user_id)

    if not team or team.club_id != club_id:
        raise ValueError("Team not found")
    if (
        not user
        or user.club_id != club_id
        or not user.is_active
        or user.club_role != ClubRole.MANAGER.value
    ):
        raise ValueError("Manager not found")

    result = await db.execute(
        select(TeamManager).where(
            TeamManager.team_id == team_id,
            TeamManager.user_id == user_id,
        )
    )
    assignment = result.scalar_one_or_none()
    if assignment:
        return assignment

    assignment = TeamManager(team_id=team_id, user_id=user_id)
    db.add(assignment)
    await db.commit()
    await db.refresh(assignment)
    return assignment


async def assign_game_operator(
    db: AsyncSession,
    club_id: uuid.UUID,
    game_id: uuid.UUID,
    user_id: uuid.UUID,
):
    game = await db.get(Game, game_id)
    user = await db.get(User, user_id)

    if not game or game.club_id != club_id:
        raise ValueError("Game not found")
    if (
        not user
        or user.club_id != club_id
        or not user.is_active
        or user.club_role != ClubRole.OPERATOR.value
    ):
        raise ValueError("Operator not found")

    result = await db.execute(
        select(GameOperator).where(
            GameOperator.game_id == game_id,
            GameOperator.user_id == user_id,
        )
    )
    assignment = result.scalar_one_or_none()
    if assignment:
        return assignment

    assignment = GameOperator(game_id=game_id, user_id=user_id)
    db.add(assignment)
    await db.commit()
    await db.refresh(assignment)
    return assignment


async def remove_team_manager(
    db: AsyncSession,
    club_id: uuid.UUID,
    team_id: uuid.UUID,
    user_id: uuid.UUID,
):
    team = await db.get(Team, team_id)
    if not team or team.club_id != club_id:
        raise ValueError("Team not found")

    await db.execute(
        delete(TeamManager).where(
            TeamManager.team_id == team_id,
            TeamManager.user_id == user_id,
        )
    )
    await db.commit()


async def remove_game_operator(
    db: AsyncSession,
    club_id: uuid.UUID,
    game_id: uuid.UUID,
    user_id: uuid.UUID,
):
    game = await db.get(Game, game_id)
    if not game or game.club_id != club_id:
        raise ValueError("Game not found")

    await db.execute(
        delete(GameOperator).where(
            GameOperator.game_id == game_id,
            GameOperator.user_id == user_id,
        )
    )
    await db.commit()


async def assignments(db: AsyncSession, club_id: uuid.UUID):
    team_rows = await db.execute(
        select(TeamManager, Team, User)
        .join(Team, Team.id == TeamManager.team_id)
        .join(User, User.id == TeamManager.user_id)
        .where(
            Team.club_id == club_id,
            User.club_id == club_id,
        )
    )
    game_rows = await db.execute(
        select(GameOperator, Game, User)
        .join(Game, Game.id == GameOperator.game_id)
        .join(User, User.id == GameOperator.user_id)
        .where(
            Game.club_id == club_id,
            User.club_id == club_id,
        )
    )

    return {
        "team_managers": [
            {
                "team_id": str(team.id),
                "team_name": team.name,
                "user_id": str(user.id),
                "user_name": user.display_name or user.email,
            }
            for _, team, user in team_rows.all()
        ],
        "game_operators": [
            {
                "game_id": str(game.id),
                "game_name": game.name,
                "user_id": str(user.id),
                "user_name": user.display_name or user.email,
            }
            for _, game, user in game_rows.all()
        ],
    }
