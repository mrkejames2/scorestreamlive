"""Provider price mapping for an internal ScoreStreamLive Plan."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class BillingPriceReference(Base):
    __tablename__ = "billing_price_references"
    __table_args__ = (
        UniqueConstraint("provider", "external_price_id", name="uq_billing_price_external"),
        Index(
            "uq_billing_price_active_plan_provider",
            "plan_id",
            "provider",
            unique=True,
            postgresql_where=text("is_active IS TRUE"),
        ),
        CheckConstraint("unit_amount_minor >= 0", name="ck_billing_price_nonnegative"),
        CheckConstraint("billing_interval IN ('month','year')", name="ck_billing_price_interval"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    plan_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("plans.id", ondelete="CASCADE"), nullable=False, index=True
    )
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    external_price_id: Mapped[str] = mapped_column(String(255), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    billing_interval: Mapped[str] = mapped_column(String(16), nullable=False)
    unit_amount_minor: Mapped[int] = mapped_column(Integer, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utc_now
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now
    )
