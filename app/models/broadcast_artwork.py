"""Reusable club-owned broadcast artwork."""
import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
class BroadcastArtwork(Base):
    __tablename__="broadcast_artworks"
    __table_args__=(UniqueConstraint("club_id","image_url",name="uq_broadcast_artworks_club_image_url"),)
    id:Mapped[uuid.UUID]=mapped_column(primary_key=True,default=uuid.uuid4)
    club_id:Mapped[uuid.UUID]=mapped_column(ForeignKey("clubs.id",ondelete="RESTRICT"),nullable=False,index=True)
    name:Mapped[str]=mapped_column(String(255),nullable=False)
    image_url:Mapped[str]=mapped_column(String(500),nullable=False)
    created_by_user_id:Mapped[Optional[uuid.UUID]]=mapped_column(ForeignKey("users.id",ondelete="SET NULL"),nullable=True)
    created_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
    updated_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
    club=relationship("Club");created_by=relationship("User")
