"""ScoringEvent domain model."""

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import ForeignKey, String, DateTime, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ScoringEvent(Base):
    """A scoring event recorded during a Game."""

    __tablename__ = "scoring_events"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)

    game_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("games.id", ondelete="RESTRICT"),
        nullable=False,
    )

    team_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("teams.id", ondelete="RESTRICT"),
        nullable=False,
    )

    player_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("players.id", ondelete="RESTRICT"),
        nullable=True,
    )

    event_type: Mapped[str] = mapped_column(String(50), nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    __table_args__ = (
        Index("ix_scoring_events_game_id", "game_id"),
    )