from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field
class GameSponsorReplace(BaseModel): sponsor_ids: list[UUID] = Field(default_factory=list)
class GameSponsorResponse(BaseModel):
    sponsor_id: UUID
    name: str
    website_url: str | None = None
    artwork_url: str | None = None
    is_active: bool
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    display_order: int
