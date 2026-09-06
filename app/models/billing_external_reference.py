"""Provider external-reference model for M18-A."""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class BillingExternalReference(Base):
    """Maps provider-owned identifiers to ScoreStreamLive-owned domain objects."""

    __tablename__ = "billing_external_references"
    __table_args__ = (
        UniqueConstraint(
            "provider",
            "resource_type",
            "external_id",
            name="uq_billing_external_reference",
        ),
        CheckConstraint(
            "(club_id IS NOT NULL AND subscription_id IS NULL) OR "
            "(club_id IS NULL AND subscription_id IS NOT NULL)",
            name="ck_billing_external_reference_owner",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    resource_type: Mapped[str] = mapped_column(String(40), nullable=False)
    external_id: Mapped[str] = mapped_column(String(255), nullable=False)
    club_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("clubs.id", ondelete="CASCADE"), nullable=True, index=True
    )
    subscription_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("subscriptions.id", ondelete="CASCADE"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utc_now
    )
