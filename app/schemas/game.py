"""Game Pydantic schemas."""

from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.team import TeamBrief


class GameStatus(str, Enum):
    """Allowed game lifecycle states."""

    SCHEDULED = "scheduled"
    LIVE = "live"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class GameBase(BaseModel):
    """Shared Game fields."""

    name: str = Field(..., min_length=1, max_length=255)
    status: GameStatus = GameStatus.SCHEDULED
    scheduled_at: Optional[datetime] = None
    home_team_id: Optional[UUID] = None
    away_team_id: Optional[UUID] = None


class GameCreate(GameBase):
    """Fields required to create a Game."""

    pass


class GameBroadcastMessageUpdate(BaseModel):
    """Operator-controlled persistent broadcast message."""

    message: Optional[str] = Field(None, max_length=500)


class GameUpdate(BaseModel):
    """Fields allowed when updating a Game."""

    name: Optional[str] = Field(None, min_length=1, max_length=255)
    status: Optional[GameStatus] = None
    scheduled_at: Optional[datetime] = None
    home_team_id: Optional[UUID] = None
    away_team_id: Optional[UUID] = None


class GameResponse(GameBase):
    """Full Game representation returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime
    home_team: Optional[TeamBrief] = None
    away_team: Optional[TeamBrief] = None
    home_score: int
    away_score: int
    broadcast_message: Optional[str] = None