"""GameClock Pydantic schemas."""

from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class ClockMode(str, Enum):
    """Supported generic clock display modes."""

    COUNT_UP = "count_up"
    COUNT_DOWN = "count_down"


class ClockStatus(str, Enum):
    """Persisted GameClock states."""

    STOPPED = "stopped"
    RUNNING = "running"
    PAUSED = "paused"


class GameClockCreate(BaseModel):
    """Fields required to initialize a GameClock."""

    mode: ClockMode
    duration_seconds: int = Field(..., gt=0)


class GameClockCommand(BaseModel):
    """Optimistic-concurrency token for clock state transitions."""

    expected_version: int = Field(..., ge=1)


class GameClockUpdate(BaseModel):
    """Clock configuration mutation allowed while not running."""

    expected_version: int = Field(..., ge=1)
    mode: Optional[ClockMode] = None
    duration_seconds: Optional[int] = Field(None, gt=0)

    @model_validator(mode="after")
    def require_configuration_change(self):
        """Require at least one configuration field."""
        if self.mode is None and self.duration_seconds is None:
            raise ValueError("At least one clock configuration field is required")
        return self


class GameClockResponse(BaseModel):
    """Authoritative GameClock state plus derived synchronization metadata."""

    id: UUID
    game_id: UUID
    mode: ClockMode
    status: ClockStatus
    duration_seconds: int
    elapsed_seconds: int
    running_since: Optional[datetime]
    version: int
    created_at: datetime
    updated_at: datetime

    # Derived at response time; not persisted.
    server_time: datetime
    authoritative_elapsed_seconds: int
    display_seconds: int
