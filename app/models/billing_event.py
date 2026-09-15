"""Durable verified billing-event inbox."""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import CheckConstraint, DateTime, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class BillingEvent(Base):
    __tablename__ = "billing_events"
    __table_args__ = (
        UniqueConstraint("provider", "external_event_id", name="uq_billing_events_provider_external_event"),
        CheckConstraint(
            "processing_status IN ('RECEIVED', 'PROCESSED', 'FAILED', 'IGNORED')",
            name="ck_billing_events_processing_status",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    external_event_id: Mapped[str] = mapped_column(String(255), nullable=False)
    event_type: Mapped[str] = mapped_column(String(255), nullable=False)
    object_external_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    # M18-H: persist the related provider subscription identity separately from
    # the event object identity (e.g. invoice ID) so FAILED lifecycle events can
    # be deterministically replayed without retaining the full provider payload.
    subscription_external_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    provider_created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    payload_digest: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    processing_status: Mapped[str] = mapped_column(String(20), nullable=False, default="RECEIVED")
    attempt_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    processed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)
