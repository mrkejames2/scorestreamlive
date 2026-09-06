"""Pre-provisioning public signup intent."""
import uuid
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import DateTime, Index, String, text
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base
def utc_now(): return datetime.now(timezone.utc)
class SignupIntent(Base):
    __tablename__="signup_intents"
    __table_args__=(
        Index(
            "uq_signup_intents_active_email",
            "email_normalized",
            unique=True,
            postgresql_where=text("status IN ('PENDING','READY_FOR_CHECKOUT')"),
        ),
    )
    id:Mapped[uuid.UUID]=mapped_column(primary_key=True,default=uuid.uuid4)
    email:Mapped[str]=mapped_column(String(320),nullable=False)
    email_normalized:Mapped[str]=mapped_column(String(320),nullable=False,index=True)
    first_name:Mapped[str]=mapped_column(String(100),nullable=False)
    last_name:Mapped[str]=mapped_column(String(100),nullable=False)
    organization_name:Mapped[str]=mapped_column(String(180),nullable=False)
    status:Mapped[str]=mapped_column(String(24),nullable=False,default="PENDING",index=True)
    created_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False,default=utc_now)
    updated_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False,default=utc_now,onupdate=utc_now)
    expires_at:Mapped[datetime]=mapped_column(DateTime(timezone=True),nullable=False)
    checkout_started_at:Mapped[Optional[datetime]]=mapped_column(DateTime(timezone=True),nullable=True)
    completed_at:Mapped[Optional[datetime]]=mapped_column(DateTime(timezone=True),nullable=True)
    source:Mapped[Optional[str]]=mapped_column(String(80),nullable=True)
