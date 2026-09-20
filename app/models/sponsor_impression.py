"""M19-G durable tracked sponsor appearance interval."""
import uuid
from datetime import datetime
from sqlalchemy import DateTime, ForeignKey, Integer, String, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base
class SponsorImpression(Base):
    __tablename__="sponsor_impressions"
    __table_args__=(CheckConstraint("duration_seconds IS NULL OR duration_seconds >= 0",name="ck_sponsor_impressions_duration_nonnegative"),)
    id:Mapped[uuid.UUID]=mapped_column(primary_key=True,default=uuid.uuid4)
    club_id:Mapped[uuid.UUID]=mapped_column(ForeignKey("clubs.id",ondelete="RESTRICT"),nullable=False,index=True)
    game_id:Mapped[uuid.UUID]=mapped_column(ForeignKey("games.id",ondelete="CASCADE"),nullable=False,index=True)
    sponsor_id:Mapped[uuid.UUID|None]=mapped_column(ForeignKey("sponsors.id",ondelete="SET NULL"),nullable=True,index=True)
    sponsor_name:Mapped[str]=mapped_column(String(255),nullable=False)
    started_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
    ended_at:Mapped[datetime|None]=mapped_column(DateTime(timezone=True),nullable=True)
    duration_seconds:Mapped[int|None]=mapped_column(Integer,nullable=True)
    trigger:Mapped[str]=mapped_column(String(32),nullable=False)
    created_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
