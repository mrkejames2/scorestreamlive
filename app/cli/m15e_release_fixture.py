"""M15-E local-only tenant isolation fixture setup/cleanup.

Creates uniquely-prefixed disposable Clubs, Users, Teams, Games, and role
assignments. This command is intended only for local validation.
"""

import argparse
import asyncio
import json
import uuid
from datetime import datetime, timezone

from sqlalchemy import delete, select

import app.models  # noqa: F401
from app.database import AsyncSessionLocal
from app.models.club import Club
from app.models.game import Game
from app.models.game_operator import GameOperator
from app.models.team import Team
from app.models.team_manager import TeamManager
from app.models.user import User
from app.models.user_session import UserSession
from app.services.auth_service import hash_password

PREFIX = "M15E-VALIDATION-"
PASSWORD = "M15E-Release-Only-2026!"


def now():
    return datetime.now(timezone.utc)


async def cleanup_prefix(db):
    users = (
        await db.execute(
            select(User).where(User.email.like("m15e-validation-%@example.invalid"))
        )
    ).scalars().all()
    user_ids = [u.id for u in users]

    clubs = (
        await db.execute(
            select(Club).where(Club.name.like(f"{PREFIX}%"))
        )
    ).scalars().all()
    club_ids = [c.id for c in clubs]

    teams = []
    games = []
    if club_ids:
        teams = (
            await db.execute(select(Team).where(Team.club_id.in_(club_ids)))
        ).scalars().all()
        games = (
            await db.execute(select(Game).where(Game.club_id.in_(club_ids)))
        ).scalars().all()

    team_ids = [t.id for t in teams]
    game_ids = [g.id for g in games]

    if game_ids:
        await db.execute(delete(GameOperator).where(GameOperator.game_id.in_(game_ids)))
    if team_ids:
        await db.execute(delete(TeamManager).where(TeamManager.team_id.in_(team_ids)))
    if user_ids:
        await db.execute(delete(UserSession).where(UserSession.user_id.in_(user_ids)))
    if game_ids:
        await db.execute(delete(Game).where(Game.id.in_(game_ids)))
    if team_ids:
        await db.execute(delete(Team).where(Team.id.in_(team_ids)))
    if user_ids:
        await db.execute(delete(User).where(User.id.in_(user_ids)))
    if club_ids:
        await db.execute(delete(Club).where(Club.id.in_(club_ids)))

    await db.commit()


async def setup():
    suffix = uuid.uuid4().hex[:8]
    async with AsyncSessionLocal() as db:
        await cleanup_prefix(db)

        club_a = Club(name=f"{PREFIX}ALPHA-{suffix}", created_at=now(), updated_at=now())
        club_b = Club(name=f"{PREFIX}BRAVO-{suffix}", created_at=now(), updated_at=now())
        db.add_all([club_a, club_b])
        await db.flush()

        def user(email_role, display, club, role, active=True):
            return User(
                email=f"m15e-validation-{suffix}-{email_role}@example.invalid",
                display_name=display,
                password_hash=hash_password(PASSWORD),
                is_active=active,
                club_id=club.id,
                club_role=role,
                created_at=now(),
                updated_at=now(),
            )

        director_a = user("director-a", "M15E Director A", club_a, "DIRECTOR")
        manager_a = user("manager-a", "M15E Manager A", club_a, "MANAGER")
        operator_a = user("operator-a", "M15E Operator A", club_a, "OPERATOR")
        disabled_a = user("disabled-a", "M15E Disabled A", club_a, "OPERATOR", False)
        director_b = user("director-b", "M15E Director B", club_b, "DIRECTOR")

        db.add_all([director_a, manager_a, operator_a, disabled_a, director_b])
        await db.flush()

        # Duplicate names across tenants are intentional and prove independence.
        a1 = Team(
            club_id=club_a.id,
            name="Heritage Hawks",
            short_name="HAWKS",
            created_at=now(),
            updated_at=now(),
        )
        a2 = Team(
            club_id=club_a.id,
            name="Midland Chemics",
            short_name="CHEMICS",
            created_at=now(),
            updated_at=now(),
        )
        a3 = Team(
            club_id=club_a.id,
            name="Okemos Wolves",
            short_name="WOLVES",
            created_at=now(),
            updated_at=now(),
        )
        b1 = Team(
            club_id=club_b.id,
            name="Heritage Hawks",
            short_name="HAWKS",
            created_at=now(),
            updated_at=now(),
        )
        b2 = Team(
            club_id=club_b.id,
            name="Midland Chemics",
            short_name="CHEMICS",
            created_at=now(),
            updated_at=now(),
        )
        db.add_all([a1, a2, a3, b1, b2])
        await db.flush()

        game_a_managed = Game(
            club_id=club_a.id,
            name="M15E Alpha Managed Game",
            status="scheduled",
            home_team_id=a1.id,
            away_team_id=a2.id,
            home_score=0,
            away_score=0,
            created_at=now(),
            updated_at=now(),
        )
        game_a_unassigned = Game(
            club_id=club_a.id,
            name="M15E Alpha Unassigned Game",
            status="scheduled",
            home_team_id=a2.id,
            away_team_id=a3.id,
            home_score=0,
            away_score=0,
            created_at=now(),
            updated_at=now(),
        )
        game_b = Game(
            club_id=club_b.id,
            name="M15E Bravo Game",
            status="scheduled",
            home_team_id=b1.id,
            away_team_id=b2.id,
            home_score=0,
            away_score=0,
            created_at=now(),
            updated_at=now(),
        )
        db.add_all([game_a_managed, game_a_unassigned, game_b])
        await db.flush()

        db.add(
            TeamManager(team_id=a1.id, user_id=manager_a.id)
        )
        db.add(
            GameOperator(game_id=game_a_managed.id, user_id=operator_a.id)
        )

        await db.commit()

        data = {
            "password": PASSWORD,
            "director_a_email": director_a.email,
            "manager_a_email": manager_a.email,
            "operator_a_email": operator_a.email,
            "disabled_a_email": disabled_a.email,
            "director_b_email": director_b.email,
            "club_a_id": str(club_a.id),
            "club_b_id": str(club_b.id),
            "team_a1_id": str(a1.id),
            "team_a2_id": str(a2.id),
            "team_a3_id": str(a3.id),
            "team_b1_id": str(b1.id),
            "team_b2_id": str(b2.id),
            "game_a_managed_id": str(game_a_managed.id),
            "game_a_unassigned_id": str(game_a_unassigned.id),
            "game_b_id": str(game_b.id),
        }
        print(json.dumps(data))


async def cleanup():
    async with AsyncSessionLocal() as db:
        await cleanup_prefix(db)
        print("M15-E validation fixtures cleaned.")


async def main_async():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["setup", "cleanup"])
    args = parser.parse_args()

    if args.action == "setup":
        await setup()
    else:
        await cleanup()


def main():
    asyncio.run(main_async())


if __name__ == "__main__":
    main()
