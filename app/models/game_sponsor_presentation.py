"""M19-E durable per-game live sponsor presentation state."""
import uuid
from datetime import datetime
from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base
class GameSponsorPresentation(Base):
    __tablename__="game_sponsor_presentations"
    __table_args__=(CheckConstraint("rotation_interval_seconds IN (5,10,15,20,30,45,60)",name="ck_game_sponsor_presentations_interval"),)
    game_id:Mapped[uuid.UUID]=mapped_column(ForeignKey("games.id",ondelete="CASCADE"),primary_key=True)
    current_sponsor_id:Mapped[uuid.UUID|None]=mapped_column(ForeignKey("sponsors.id",ondelete="SET NULL"),nullable=True,index=True)
    visible:Mapped[bool]=mapped_column(Boolean,nullable=False,default=True)
    rotation_enabled:Mapped[bool]=mapped_column(Boolean,nullable=False,default=True)
    rotation_interval_seconds:Mapped[int]=mapped_column(Integer,nullable=False,default=10)
    version:Mapped[int]=mapped_column(Integer,nullable=False,default=1)
    created_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
    updated_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
