"""Player Pydantic schemas."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class PlayerBase(BaseModel):
    """Shared Player fields."""

    team_id: UUID
    first_name: str = Field(..., min_length=1, max_length=255)
    last_name: str = Field(..., min_length=1, max_length=255)
    jersey_number: Optional[int] = Field(None, ge=0, le=999)

    @field_validator("first_name", "last_name")
    @classmethod
    def strip_and_check_names(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("cannot be empty")
        return v


class PlayerCreate(PlayerBase):
    """Fields required to create a Player."""

    pass


class PlayerUpdate(BaseModel):
    """Fields allowed when updating a Player."""

    first_name: Optional[str] = Field(None, min_length=1, max_length=255)
    last_name: Optional[str] = Field(None, min_length=1, max_length=255)
    jersey_number: Optional[int] = Field(None, ge=0, le=999)

    @field_validator("first_name", "last_name")
    @classmethod
    def strip_and_check_names(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v = v.strip()
            if not v:
                raise ValueError("cannot be empty")
        return v


class PlayerResponse(PlayerBase):
    """Full Player representation returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime