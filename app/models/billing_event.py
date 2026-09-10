"""Auditable verified provider-event persistence model."""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import CheckConstraint, DateTime, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

BILLING_EVENT_STATUSES = ("RECEIVED", "PROCESSED", "FAILED", "IGNORED")

def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class BillingEvent(Base):
    __tablename__ = "billing_events"
    __table_args__ = (
        UniqueConstraint("provider", "external_event_id", name="uq_billing_event_provider_event"),
        CheckConstraint("processing_status IN ('RECEIVED', 'PROCESSED', 'FAILED', 'IGNORED')", name="ck_billing_events_processing_status"),
        CheckConstraint("attempt_count >= 0", name="ck_billing_events_attempt_count"),
        Index("ix_billing_events_processing_status", "processing_status"),
        Index("ix_billing_events_object", "provider", "object_external_id"),
    )
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    external_event_id: Mapped[str] = mapped_column(String(255), nullable=False)
    event_type: Mapped[str] = mapped_column(String(160), nullable=False)
    object_external_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    processing_status: Mapped[str] = mapped_column(String(20), nullable=False, default="RECEIVED")
    attempt_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    payload_digest: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    provider_created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    processed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
