"""One-time password-reset token model for M17-E."""
import uuid
from datetime import datetime, timezone
from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

def utc_now(): return datetime.now(timezone.utc)

class UserPasswordReset(Base):
    __tablename__="user_password_resets"
    id: Mapped[uuid.UUID]=mapped_column(primary_key=True,default=uuid.uuid4)
    user_id: Mapped[uuid.UUID]=mapped_column(ForeignKey("users.id",ondelete="CASCADE"),nullable=False,index=True)
    token_hash: Mapped[str]=mapped_column(String(64),nullable=False,unique=True,index=True)
    expires_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
    used_at: Mapped[datetime|None]=mapped_column(DateTime(timezone=True),nullable=True)
    revoked_at: Mapped[datetime|None]=mapped_column(DateTime(timezone=True),nullable=True)
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False,default=utc_now)
    user=relationship("User")
