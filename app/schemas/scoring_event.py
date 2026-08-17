"""ScoringEvent Pydantic schemas."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ScoringEventCreate(BaseModel):
    """Fields accepted from a scoring client."""

    game_id: UUID
    team_id: UUID
    player_id: Optional[UUID] = None
    event_type: str = Field(..., min_length=1, max_length=50)


class ScoringEventResponse(BaseModel):
    """Committed scoring event returned by REST and Socket.IO."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    game_id: UUID
    team_id: UUID
    player_id: Optional[UUID] = None
    event_type: str

    # Server-computed match time. Clients never submit this value.
    game_elapsed_seconds: Optional[int] = None

    created_at: datetime
