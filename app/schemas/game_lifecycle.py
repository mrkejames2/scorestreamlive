"""GameLifecycle Pydantic schemas."""

from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field


class LifecyclePhase(str, Enum):
    PREGAME = "pregame"
    FIRST_HALF = "first_half"
    HALFTIME = "halftime"
    SECOND_HALF = "second_half"
    FULL_TIME = "full_time"


class LifecycleAction(str, Enum):
    START_FIRST_HALF = "start_first_half"
    END_FIRST_HALF = "end_first_half"
    START_SECOND_HALF = "start_second_half"
    END_GAME = "end_game"


class GameLifecycleCreate(BaseModel):
    pass


class GameLifecycleTransition(BaseModel):
    action: LifecycleAction
    expected_lifecycle_version: int = Field(..., ge=1)
    expected_clock_version: int = Field(..., ge=1)


class GameLifecycleResponse(BaseModel):
    id: UUID
    game_id: UUID
    phase: LifecyclePhase
    version: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class GameClockTransitionState(BaseModel):
    id: UUID
    game_id: UUID
    mode: str
    status: str
    duration_seconds: int
    elapsed_seconds: int
    running_since: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime
    server_time: datetime
    authoritative_elapsed_seconds: int
    display_seconds: int


class GameLifecycleTransitionResponse(BaseModel):
    transition_id: UUID
    lifecycle: GameLifecycleResponse
    clock: GameClockTransitionState
