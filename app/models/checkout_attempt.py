"""Recoverable application-side hosted checkout attempt."""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class CheckoutAttempt(Base):
    __tablename__ = "checkout_attempts"
    __table_args__ = (
        UniqueConstraint("idempotency_key", name="uq_checkout_attempt_idempotency"),
        Index(
            "uq_checkout_attempt_active",
            "signup_intent_id",
            "plan_id",
            "provider",
            unique=True,
            postgresql_where=text("status IN ('CREATING','OPEN')"),
        ),
        CheckConstraint(
            "status IN ('CREATING','OPEN','EXPIRED','COMPLETED','FAILED','CANCELED')",
            name="ck_checkout_attempt_status",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    signup_intent_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("signup_intents.id", ondelete="CASCADE"), nullable=False, index=True
    )
    plan_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("plans.id", ondelete="RESTRICT"), nullable=False
    )
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="CREATING")
    idempotency_key: Mapped[str] = mapped_column(String(160), nullable=False)
    checkout_url: Mapped[Optional[str]] = mapped_column(String(2048), nullable=True)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utc_now
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now
    )
