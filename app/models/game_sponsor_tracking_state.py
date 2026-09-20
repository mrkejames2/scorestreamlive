"""M19-G durable per-game sponsor tracking cursor."""
import uuid
from datetime import datetime
from sqlalchemy import Boolean,DateTime,ForeignKey,Integer
from sqlalchemy.orm import Mapped,mapped_column
from app.database import Base
class GameSponsorTrackingState(Base):
    __tablename__="game_sponsor_tracking_states"
    game_id:Mapped[uuid.UUID]=mapped_column(ForeignKey("games.id",ondelete="CASCADE"),primary_key=True)
    active_sponsor_id:Mapped[uuid.UUID|None]=mapped_column(ForeignKey("sponsors.id",ondelete="SET NULL"),nullable=True)
    active_impression_id:Mapped[uuid.UUID|None]=mapped_column(ForeignKey("sponsor_impressions.id",ondelete="SET NULL"),nullable=True)
    tracking_active:Mapped[bool]=mapped_column(Boolean,nullable=False,default=False)
    last_reconciled_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
    version:Mapped[int]=mapped_column(Integer,nullable=False,default=1)
    created_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
    updated_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
