"""GameLifecycle domain model."""

import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class GameLifecycle(Base):
    """Authoritative competition phase state for a Game."""

    __tablename__ = "game_lifecycles"

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True,
        default=uuid.uuid4,
    )

    game_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("games.id", ondelete="RESTRICT"),
        nullable=False,
    )

    phase: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="pregame",
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
            name="uq_game_lifecycles_game_id",
        ),
        CheckConstraint(
            "phase IN ("
            "'pregame', "
            "'first_half', "
            "'halftime', "
            "'second_half', "
            "'full_time'"
            ")",
            name="ck_game_lifecycles_phase",
        ),
        CheckConstraint(
            "version >= 1",
            name="ck_game_lifecycles_version_positive",
        ),
    )
