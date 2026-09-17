from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, HttpUrl, model_validator

class SponsorCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    website_url: Optional[HttpUrl] = None
    is_active: bool = True
    display_order: int = 0
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None

    @model_validator(mode="after")
    def valid_window(self):
        if self.starts_at and self.ends_at and self.ends_at < self.starts_at:
            raise ValueError("ends_at must be greater than or equal to starts_at")
        return self

class SponsorUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    website_url: Optional[HttpUrl] = None
    is_active: Optional[bool] = None
    display_order: Optional[int] = None
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None

class SponsorResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    club_id: UUID
    name: str
    website_url: Optional[str] = None
    artwork_url: Optional[str] = None
    is_active: bool
    display_order: int
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
