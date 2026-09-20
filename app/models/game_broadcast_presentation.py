import uuid
from datetime import datetime
from sqlalchemy import CheckConstraint,DateTime,ForeignKey,Integer,String
from sqlalchemy.orm import Mapped,mapped_column
from app.database import Base
class GameBroadcastPresentation(Base):
    __tablename__="game_broadcast_presentations"
    __table_args__=(CheckConstraint("scene IN ('intro','live')",name="ck_game_broadcast_presentations_scene"),)
    game_id:Mapped[uuid.UUID]=mapped_column(ForeignKey("games.id",ondelete="CASCADE"),primary_key=True)
    scene:Mapped[str]=mapped_column(String(20),nullable=False,default="live")
    version:Mapped[int]=mapped_column(Integer,nullable=False,default=1)
    created_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
    updated_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
