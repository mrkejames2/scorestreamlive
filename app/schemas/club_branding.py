from typing import Optional
from pydantic import BaseModel, ConfigDict, Field
HEX_COLOR_PATTERN = r"^#[0-9A-Fa-f]{6}$"
class ClubBrandingUpdate(BaseModel):
    display_name: Optional[str] = Field(None, min_length=1, max_length=255)
    short_name: Optional[str] = Field(None, min_length=1, max_length=100)
    primary_color: Optional[str] = Field(None, pattern=HEX_COLOR_PATTERN)
    secondary_color: Optional[str] = Field(None, pattern=HEX_COLOR_PATTERN)
class ClubBrandingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    display_name: Optional[str] = None
    short_name: Optional[str] = None
    logo_url: Optional[str] = None
    primary_color: Optional[str] = None
    secondary_color: Optional[str] = None
