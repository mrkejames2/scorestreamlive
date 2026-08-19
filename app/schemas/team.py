"""Team Pydantic schemas."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


HEX_COLOR_PATTERN = r"^#[0-9A-Fa-f]{6}$"


class TeamBrief(BaseModel):
    """Minimal Team representation for embedding in other responses."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    short_name: Optional[str] = None
    logo_url: Optional[str] = None
    primary_color: Optional[str] = None
    secondary_color: Optional[str] = None


class TeamBase(BaseModel):
    """Shared Team fields."""

    name: str = Field(..., min_length=1, max_length=255)
    short_name: Optional[str] = Field(None, min_length=1, max_length=100)
    logo_url: Optional[str] = Field(None, max_length=500)
    primary_color: Optional[str] = Field(None, pattern=HEX_COLOR_PATTERN)
    secondary_color: Optional[str] = Field(None, pattern=HEX_COLOR_PATTERN)


class TeamCreate(TeamBase):
    """Fields required to create a Team."""

    pass


class TeamUpdate(BaseModel):
    """Fields allowed when updating a Team."""

    name: Optional[str] = Field(None, min_length=1, max_length=255)
    short_name: Optional[str] = Field(None, min_length=1, max_length=100)
    logo_url: Optional[str] = Field(None, max_length=500)
    primary_color: Optional[str] = Field(None, pattern=HEX_COLOR_PATTERN)
    secondary_color: Optional[str] = Field(None, pattern=HEX_COLOR_PATTERN)


class TeamResponse(TeamBase):
    """Full Team representation returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime
