"""Club-owned sponsor domain model."""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

def utc_now() -> datetime:
    return datetime.now(timezone.utc)

class Sponsor(Base):
    __tablename__ = "sponsors"
    __table_args__ = (
        CheckConstraint(
            "ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at",
            name="ck_sponsors_valid_date_window",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    club_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("clubs.id", ondelete="CASCADE"), nullable=False, index=True
    )
    club: Mapped["Club"] = relationship("Club")
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    website_url: Mapped[Optional[str]] = mapped_column(String(2048), nullable=True)
    artwork_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    starts_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    ends_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)
