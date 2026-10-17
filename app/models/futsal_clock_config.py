"""Per-game futsal clock configuration; existing generic GameClock remains authoritative."""
import uuid
from datetime import datetime
from sqlalchemy import ForeignKey, Integer, String, DateTime, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class FutsalClockConfig(Base):
    __tablename__ = 'futsal_clock_configs'
    game_id: Mapped[uuid.UUID] = mapped_column(ForeignKey('games.id', ondelete='CASCADE'), primary_key=True)
    period: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    clock_policy: Mapped[str] = mapped_column(String(20), nullable=False, default='stop_clock')
    period_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=1200)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    __table_args__ = (
        CheckConstraint('period BETWEEN 1 AND 2', name='ck_futsal_clock_period'),
        CheckConstraint("clock_policy IN ('stop_clock', 'running_clock')", name='ck_futsal_clock_policy'),
        CheckConstraint('period_seconds BETWEEN 60 AND 3600', name='ck_futsal_clock_duration'),
    )
