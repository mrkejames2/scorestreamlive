"""ScoringEvent Pydantic schemas."""

from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class ScoringEventCreate(BaseModel):
    """Fields accepted from a scoring client.

    M7 scoring semantics intentionally support only a goal. Other soccer
    events such as penalties/cards/substitutions are separate future domain
    concepts and must not increment Game score through this endpoint.
    """

    game_id: UUID
    team_id: UUID
    player_id: Optional[UUID] = None
    event_type: Literal["goal"]


class ScoringEventResponse(BaseModel):
    """Committed scoring event returned by REST and Socket.IO."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    game_id: UUID
    team_id: UUID
    player_id: Optional[UUID] = None
    event_type: Literal["goal"]

    # Added in the M10-E human-acceptance cleanup. It is server-computed
    # from the authoritative GameClock and may be NULL only for historical
    # pre-migration records or legacy games without a clock.
    game_elapsed_seconds: Optional[int] = None

    created_at: datetime
