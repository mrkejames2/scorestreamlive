"""Team Pydantic schemas."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class TeamBrief(BaseModel):
    """Minimal Team representation for embedding in other responses."""

    model_config = ConfigDict(from_attributes=True)
    id: UUID
    name: str
    short_name: Optional[str] = None


class TeamBase(BaseModel):
    """Shared Team fields."""

    name: str = Field(..., min_length=1, max_length=255)
    short_name: Optional[str] = Field(None, min_length=1, max_length=100)


class TeamCreate(TeamBase):
    """Fields required to create a Team."""

    pass


class TeamUpdate(BaseModel):
    """Fields allowed when updating a Team."""

    name: Optional[str] = Field(None, min_length=1, max_length=255)
    short_name: Optional[str] = Field(None, min_length=1, max_length=100)


class TeamResponse(TeamBase):
    """Full Team representation returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime