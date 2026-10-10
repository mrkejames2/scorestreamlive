from pydantic import BaseModel, Field

class AnnouncementItemIn(BaseModel):
    number: str = Field(default="", max_length=20)
    name: str = Field(min_length=1, max_length=120)
    subtitle: str = Field(default="", max_length=160)

class AnnouncementListIn(BaseModel):
    title: str = Field(default="SENIOR NIGHT", min_length=1, max_length=100)
    items: list[AnnouncementItemIn] = Field(max_length=100)
    expected_version: int = Field(ge=0)

class AnnouncementCommandIn(BaseModel):
    action: str
    item_id: str | None = None
    expected_version: int = Field(ge=0)
