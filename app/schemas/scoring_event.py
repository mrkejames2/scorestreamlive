"""ScoringEvent Pydantic schemas."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ScoringEventCreate(BaseModel):
    """Fields required to create a ScoringEvent."""

    game_id: UUID
    team_id: UUID
    player_id: Optional[UUID] = None
    event_type: str = Field(..., min_length=1, max_length=50)

    @field_validator("event_type")
    @classmethod
    def validate_event_type(cls, v: str) -> str:
        if v != "goal":
            raise ValueError("event_type must be 'goal'")
        return v


class ScoringEventResponse(BaseModel):
    """Full ScoringEvent representation returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    game_id: UUID
    team_id: UUID
    player_id: Optional[UUID] = None
    event_type: str
    created_at: datetime