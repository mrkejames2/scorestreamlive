import uuid
from datetime import datetime
from sqlalchemy import Boolean,DateTime,ForeignKey,Integer,UniqueConstraint
from sqlalchemy.orm import Mapped,mapped_column
from app.database import Base
class GameHalftimeSlideshow(Base):
 __tablename__="game_halftime_slideshows"
 game_id:Mapped[uuid.UUID]=mapped_column(ForeignKey("games.id",ondelete="CASCADE"),primary_key=True)
 enabled:Mapped[bool]=mapped_column(Boolean,nullable=False,default=False)
 interval_seconds:Mapped[int]=mapped_column(Integer,nullable=False,default=10)
 created_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
 updated_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
class GameHalftimeSlideshowSlide(Base):
 __tablename__="game_halftime_slideshow_slides"
 __table_args__=(UniqueConstraint("game_id","position",name="uq_halftime_slideshow_game_position"),UniqueConstraint("game_id","artwork_id",name="uq_halftime_slideshow_game_artwork"))
 id:Mapped[uuid.UUID]=mapped_column(primary_key=True,default=uuid.uuid4)
 game_id:Mapped[uuid.UUID]=mapped_column(ForeignKey("game_halftime_slideshows.game_id",ondelete="CASCADE"),nullable=False,index=True)
 artwork_id:Mapped[uuid.UUID]=mapped_column(ForeignKey("broadcast_artworks.id",ondelete="RESTRICT"),nullable=False,index=True)
 position:Mapped[int]=mapped_column(Integer,nullable=False)
 created_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
 updated_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
