"""Club tenant model for M15-B."""
import uuid
from datetime import datetime, timezone
from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

def utc_now() -> datetime:
    return datetime.now(timezone.utc)

class Club(Base):
    """A ScoreStreamLive club/environment boundary."""
    __tablename__ = "clubs"
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)
