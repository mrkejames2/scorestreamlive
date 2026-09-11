"""Post-purchase activation for already-provisioned inactive DIRECTOR users."""
from __future__ import annotations

import hashlib
import logging
import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.password_policy import validate_password
from app.config import settings
from app.models.club import Club
from app.models.user import User
from app.models.user_account_activation import UserAccountActivation
from app.services.auth_service import get_user_by_email, hash_password, normalize_email
from app.services.email_service import EmailDeliveryError, send_account_activation_email

logger = logging.getLogger("app")


class AccountActivationInvalid(ValueError):
    pass


@dataclass(frozen=True)
class ActivationDelivery:
    activation_id: uuid.UUID
    user_id: uuid.UUID
    raw_token: str


def now() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def hash_activation_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def activation_url(token: str) -> str:
    return (
        f"{settings.PUBLIC_BASE_URL.rstrip('/')}/activate-account?"
        f"{urlencode({'token': token})}"
    )


def activation_status(record: UserAccountActivation) -> str:
    if record.used_at:
        return "USED"
    if record.revoked_at:
        return "REVOKED"
    if _aware(record.expires_at) <= now():
        return "EXPIRED"
    return "PENDING"


async def revoke_outstanding_activations(
    db: AsyncSession, user_id: uuid.UUID
) -> int:
    rows = list(
        (
            await db.scalars(
                select(UserAccountActivation).where(
                    UserAccountActivation.user_id == user_id,
                    UserAccountActivation.used_at.is_(None),
                    UserAccountActivation.revoked_at.is_(None),
                )
            )
        ).all()
    )
    ts = now()
    count = 0
    for record in rows:
        if activation_status(record) == "PENDING":
            record.revoked_at = ts
            count += 1
        elif record.revoked_at is None:
            # Expired records must no longer hold the one-pending-token invariant.
            record.revoked_at = ts
    return count


async def issue_account_activation(
    db: AsyncSession, *, user: User
) -> tuple[UserAccountActivation, str]:
    if user.is_active:
        raise AccountActivationInvalid("Account is already active")
    if user.club_role != "DIRECTOR" or user.club_id is None:
        raise AccountActivationInvalid("Account is not eligible for post-purchase activation")

    await revoke_outstanding_activations(db, user.id)
    raw = secrets.token_urlsafe(48)
    ts = now()
    record = UserAccountActivation(
        user_id=user.id,
        token_hash=hash_activation_token(raw),
        expires_at=ts + timedelta(hours=settings.ACCOUNT_ACTIVATION_TTL_HOURS),
        created_at=ts,
    )
    db.add(record)
    await db.flush()
    return record, raw


async def resolve_account_activation(
    db: AsyncSession, raw_token: str, *, for_update: bool = False
) -> tuple[UserAccountActivation, User, Club]:
    if not raw_token:
        raise AccountActivationInvalid("Activation link is invalid or expired")

    query = select(UserAccountActivation).where(
        UserAccountActivation.token_hash == hash_activation_token(raw_token)
    )
    if for_update:
        query = query.with_for_update()

    record = await db.scalar(query)
    if record is None or activation_status(record) != "PENDING":
        raise AccountActivationInvalid("Activation link is invalid or expired")

    user = await db.get(User, record.user_id)
    if (
        user is None
        or user.is_active
        or user.club_id is None
        or user.club_role != "DIRECTOR"
    ):
        raise AccountActivationInvalid("Activation link is invalid or expired")

    club = await db.get(Club, user.club_id)
    if club is None:
        raise AccountActivationInvalid("Activation link is invalid or expired")

    return record, user, club


async def consume_account_activation(
    db: AsyncSession, *, raw_token: str, password: str
) -> User:
    validate_password(password)
    record, user, _ = await resolve_account_activation(
        db, raw_token, for_update=True
    )

    ts = now()
    user.password_hash = hash_password(password)
    user.is_active = True
    user.updated_at = ts
    record.used_at = ts

    # Revoke any accidental sibling credentials before committing activation.
    siblings = list(
        (
            await db.scalars(
                select(UserAccountActivation).where(
                    UserAccountActivation.user_id == user.id,
                    UserAccountActivation.id != record.id,
                    UserAccountActivation.used_at.is_(None),
                    UserAccountActivation.revoked_at.is_(None),
                )
            )
        ).all()
    )
    for sibling in siblings:
        sibling.revoked_at = ts

    await db.commit()
    await db.refresh(user)
    return user


async def deliver_activation(
    db: AsyncSession, delivery: ActivationDelivery
) -> bool:
    """Deliver after durable provisioning commit; never raise an SMTP failure."""

    record = await db.get(UserAccountActivation, delivery.activation_id)
    user = await db.get(User, delivery.user_id)
    if record is None or user is None or user.club_id is None:
        logger.error(
            "Activation delivery state missing",
            extra={"event": "account_activation.delivery_state_missing"},
        )
        return False
    if user.is_active or activation_status(record) != "PENDING":
        return False

    club = await db.get(Club, user.club_id)
    if club is None:
        logger.error(
            "Activation delivery Club missing",
            extra={
                "event": "account_activation.club_missing",
                "user_id": str(user.id),
            },
        )
        return False

    try:
        await send_account_activation_email(
            email=user.email,
            display_name=user.display_name,
            club_name=club.name,
            activation_url=activation_url(delivery.raw_token),
            expires_at=record.expires_at,
        )
    except EmailDeliveryError:
        # Payment/provisioning has already committed. Email is recoverable delivery,
        # never billing authority and never a reason to fail the Stripe webhook.
        logger.exception(
            "Account activation email delivery failed",
            extra={
                "event": "account_activation.email.failed",
                "user_id": str(user.id),
                "activation_id": str(record.id),
            },
        )
        return False

    record.last_sent_at = now()
    await db.commit()
    logger.info(
        "Account activation email delivered",
        extra={
            "event": "account_activation.email.sent",
            "user_id": str(user.id),
            "activation_id": str(record.id),
        },
    )
    return True


async def request_activation_resend(db: AsyncSession, email: str) -> None:
    """Generic public resend path; intentionally reveals no account existence."""

    try:
        normalized = normalize_email(email)
    except Exception:
        return

    user = await get_user_by_email(db, normalized)
    if (
        user is None
        or user.is_active
        or user.club_id is None
        or user.club_role != "DIRECTOR"
    ):
        return

    latest = await db.scalar(
        select(UserAccountActivation)
        .where(UserAccountActivation.user_id == user.id)
        .order_by(UserAccountActivation.created_at.desc())
    )
    ts = now()

    # Throttle only a token that was actually delivered. A failed SMTP attempt has
    # last_sent_at=None and is immediately recoverable by issuing a fresh token.
    if (
        latest is not None
        and activation_status(latest) == "PENDING"
        and latest.last_sent_at is not None
        and (ts - _aware(latest.last_sent_at)).total_seconds()
        < settings.ACCOUNT_ACTIVATION_RESEND_SECONDS
    ):
        return

    record, raw = await issue_account_activation(db, user=user)
    await db.commit()
    await deliver_activation(
        db,
        ActivationDelivery(
            activation_id=record.id,
            user_id=user.id,
            raw_token=raw,
        ),
    )
