"""Safely claim legacy unscoped Teams/Games into an existing User's Club."""

import asyncio
import os

from sqlalchemy import update

# Register all SQLAlchemy models before the first ORM query. This is required
# for string-based relationships such as Game.club -> "Club" in standalone CLI
# execution where FastAPI router imports do not preload the model registry.
import app.models  # noqa: F401

from app.database import AsyncSessionLocal
from app.models.game import Game
from app.models.team import Team
from app.services.auth_service import get_user_by_email, normalize_email


async def main_async() -> int:
    email = normalize_email(
        os.getenv("RESOURCE_CLAIM_USER_EMAIL")
        or input("Director email: ").strip()
    )

    async with AsyncSessionLocal() as db:
        user = await get_user_by_email(db, email)
        if not user or not user.club_id:
            print("ERROR: user must exist and belong to a Club.")
            return 2

        team_result = await db.execute(
            update(Team)
            .where(Team.club_id.is_(None))
            .values(club_id=user.club_id)
        )
        game_result = await db.execute(
            update(Game)
            .where(Game.club_id.is_(None))
            .values(club_id=user.club_id)
        )
        await db.commit()

        print(f"Claimed legacy Teams: {team_result.rowcount}")
        print(f"Claimed legacy Games: {game_result.rowcount}")
        print(f"Club ID: {user.club_id}")
        return 0


def main() -> None:
    raise SystemExit(asyncio.run(main_async()))


if __name__ == "__main__":
    main()
