"""Create the initial Club and assign the M15-A bootstrap User as DIRECTOR."""
import asyncio
import os
from app.auth.roles import ClubRole
from app.database import AsyncSessionLocal
from app.services.auth_service import get_user_by_email, normalize_email
from app.services.club_service import assign_user_to_club, create_club, get_club, get_club_by_name

async def bootstrap() -> int:
    email = normalize_email(os.getenv("CLUB_BOOTSTRAP_USER_EMAIL") or input("Existing user email: ").strip())
    club_name = (os.getenv("CLUB_BOOTSTRAP_NAME") or input("Club name: ").strip()).strip()
    if not email or "@" not in email:
        print("ERROR: a valid existing user email is required.")
        return 2
    if not club_name:
        print("ERROR: club name is required.")
        return 2
    async with AsyncSessionLocal() as db:
        user = await get_user_by_email(db, email)
        if not user:
            print(f"ERROR: user does not exist: {email}")
            return 2
        if user.club_id is not None:
            club = await get_club(db, user.club_id)
            if not club:
                print("ERROR: user references a missing Club.")
                return 2
            print(f"User already assigned: {email} -> {club.name} ({user.club_role or 'NO ROLE'})")
            return 0
        club = await get_club_by_name(db, club_name)
        if club is None:
            club = await create_club(db, club_name)
        await assign_user_to_club(db, user, club, ClubRole.DIRECTOR)
        await db.commit()
        print(f"Club ready: {club.name}")
        print(f"Assigned DIRECTOR: {email}")
        return 0

def main() -> None:
    raise SystemExit(asyncio.run(bootstrap()))

if __name__ == "__main__":
    main()
