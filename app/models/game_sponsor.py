"""Per-game Sponsor assignment model for M19-C."""
import uuid
from datetime import datetime, timezone
from sqlalchemy import DateTime, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

def utc_now(): return datetime.now(timezone.utc)
class GameSponsor(Base):
    __tablename__ = "game_sponsors"
    game_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("games.id", ondelete="CASCADE"), primary_key=True)
    sponsor_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("sponsors.id", ondelete="CASCADE"), primary_key=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    game: Mapped["Game"] = relationship("Game")
    sponsor: Mapped["Sponsor"] = relationship("Sponsor")
