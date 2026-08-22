"""Create the first M15-A user without exposing public registration."""

import asyncio
import getpass
import os

from sqlalchemy.exc import IntegrityError

from app.database import AsyncSessionLocal
from app.models.user import User
from app.services.auth_service import get_user_by_email, hash_password, normalize_email


async def bootstrap() -> int:
    email = os.getenv("AUTH_BOOTSTRAP_EMAIL") or input("Email: ").strip()
    display_name = os.getenv("AUTH_BOOTSTRAP_DISPLAY_NAME") or input("Display name (optional): ").strip() or None
    password = os.getenv("AUTH_BOOTSTRAP_PASSWORD") or getpass.getpass("Password: ")

    email = normalize_email(email)
    if not email or "@" not in email:
        print("ERROR: a valid email address is required.")
        return 2
    if len(password) < 8:
        print("ERROR: password must be at least 8 characters.")
        return 2

    async with AsyncSessionLocal() as db:
        existing = await get_user_by_email(db, email)
        if existing:
            print(f"User already exists: {email}")
            return 0

        user = User(
            email=email,
            display_name=display_name,
            password_hash=hash_password(password),
            is_active=True,
        )
        db.add(user)
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            print(f"User already exists: {email}")
            return 0

        print(f"Created user: {email}")
        return 0


def main() -> None:
    raise SystemExit(asyncio.run(bootstrap()))


if __name__ == "__main__":
    main()
