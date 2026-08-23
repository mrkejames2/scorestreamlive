"""Club membership services for M15-B."""
import uuid
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.roles import ClubRole
from app.models.club import Club
from app.models.user import User

async def get_club(db: AsyncSession, club_id: uuid.UUID) -> Optional[Club]:
    result = await db.execute(select(Club).where(Club.id == club_id))
    return result.scalar_one_or_none()

async def get_club_by_name(db: AsyncSession, name: str) -> Optional[Club]:
    result = await db.execute(select(Club).where(Club.name == name.strip()))
    return result.scalars().first()

async def create_club(db: AsyncSession, name: str) -> Club:
    clean_name = name.strip()
    if not clean_name:
        raise ValueError("Club name must not be blank")
    club = Club(name=clean_name)
    db.add(club)
    await db.flush()
    return club

async def assign_user_to_club(db: AsyncSession, user: User, club: Club, role: ClubRole) -> User:
    if user.club_id is not None and user.club_id != club.id:
        raise ValueError("User already belongs to another Club")
    user.club_id = club.id
    user.club_role = role.value
    await db.flush()
    return user
