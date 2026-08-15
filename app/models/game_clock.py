"""GameClock domain model."""

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class GameClock(Base):
    """Authoritative persisted clock state for a Game."""

    __tablename__ = "game_clocks"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)

    game_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("games.id", ondelete="RESTRICT"),
        nullable=False,
    )

    mode: Mapped[str] = mapped_column(String(20), nullable=False)

    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="stopped",
    )

    duration_seconds: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    elapsed_seconds: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )

    running_since: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint(
            "game_id",
            name="uq_game_clocks_game_id",
        ),
        CheckConstraint(
            "mode IN ('count_up', 'count_down')",
            name="ck_game_clocks_mode",
        ),
        CheckConstraint(
            "status IN ('stopped', 'running', 'paused')",
            name="ck_game_clocks_status",
        ),
        CheckConstraint(
            "duration_seconds > 0",
            name="ck_game_clocks_duration_positive",
        ),
        CheckConstraint(
            "elapsed_seconds >= 0",
            name="ck_game_clocks_elapsed_nonnegative",
        ),
        CheckConstraint(
            "version >= 1",
            name="ck_game_clocks_version_positive",
        ),
    )
