"""Authentication and persistent session services for M15-A."""

import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from fastapi import Response
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.user import User
from app.models.user_session import UserSession

_password_hasher = PasswordHasher()


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def normalize_email(email: str) -> str:
    """Normalize email for identity comparison."""
    return email.strip().lower()


def hash_password(password: str) -> str:
    """Hash a plaintext password with Argon2id."""
    if not password:
        raise ValueError("Password must not be blank")
    return _password_hasher.hash(password)


def verify_password(password_hash: str, password: str) -> bool:
    """Verify a password without exposing hash failures."""
    try:
        return _password_hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def hash_session_token(token: str) -> str:
    """Hash the opaque browser token before database lookup/storage."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


async def get_user_by_email(db: AsyncSession, email: str) -> Optional[User]:
    result = await db.execute(select(User).where(User.email == normalize_email(email)))
    return result.scalar_one_or_none()


async def authenticate_user(db: AsyncSession, email: str, password: str) -> Optional[User]:
    """Return the active User when credentials are valid."""
    user = await get_user_by_email(db, email)
    if not user or not user.is_active:
        return None
    if not verify_password(user.password_hash, password):
        return None
    return user


async def create_user_session(db: AsyncSession, user: User) -> tuple[UserSession, str]:
    """Create a persistent session and return the raw cookie token once."""
    raw_token = secrets.token_urlsafe(48)
    now = utc_now()
    session = UserSession(
        id=uuid.uuid4(),
        user_id=user.id,
        token_hash=hash_session_token(raw_token),
        created_at=now,
        expires_at=now + timedelta(days=settings.AUTH_SESSION_DAYS),
        last_seen_at=now,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session, raw_token


async def resolve_session_user(db: AsyncSession, raw_token: str | None) -> Optional[User]:
    """Resolve an unexpired opaque session to an active User."""
    if not raw_token:
        return None

    token_hash = hash_session_token(raw_token)
    result = await db.execute(
        select(UserSession, User)
        .join(User, User.id == UserSession.user_id)
        .where(UserSession.token_hash == token_hash)
    )
    row = result.first()
    if not row:
        return None

    session, user = row
    now = utc_now()
    expires_at = session.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if expires_at <= now or not user.is_active:
        await db.delete(session)
        await db.commit()
        return None

    return user


async def revoke_session(db: AsyncSession, raw_token: str | None) -> None:
    """Revoke the current session if present."""
    if not raw_token:
        return
    await db.execute(
        delete(UserSession).where(UserSession.token_hash == hash_session_token(raw_token))
    )
    await db.commit()


def set_session_cookie(response: Response, raw_token: str) -> None:
    """Attach the opaque session cookie with conservative browser defaults."""
    response.set_cookie(
        key=settings.AUTH_SESSION_COOKIE_NAME,
        value=raw_token,
        max_age=settings.AUTH_SESSION_DAYS * 24 * 60 * 60,
        httponly=True,
        secure=settings.AUTH_SESSION_COOKIE_SECURE,
        samesite="lax",
        path="/",
    )


def clear_session_cookie(response: Response) -> None:
    """Expire the authentication cookie."""
    response.delete_cookie(
        key=settings.AUTH_SESSION_COOKIE_NAME,
        path="/",
        secure=settings.AUTH_SESSION_COOKIE_SECURE,
        httponly=True,
        samesite="lax",
    )
