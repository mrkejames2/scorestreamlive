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

    M16-A request_id is an optional caller-generated idempotency token.
    Replaying the same scoring command with the same request_id returns the
    already-committed event and must not increment the score again.
    """

    game_id: UUID
    team_id: UUID
    player_id: Optional[UUID] = None
    event_type: Literal["goal"]
    request_id: Optional[UUID] = None


class ScoringEventUpdate(BaseModel):
    player_id: Optional[UUID] = None


class ScoringEventResponse(BaseModel):
    """Committed scoring event returned by REST and Socket.IO."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    game_id: UUID
    team_id: UUID
    player_id: Optional[UUID] = None
    event_type: Literal["goal"]
    request_id: Optional[UUID] = None

    # Added in the M10-E human-acceptance cleanup. It is server-computed
    # from the authoritative GameClock and may be NULL only for historical
    # pre-migration records or legacy games without a clock.
    game_elapsed_seconds: Optional[int] = None

    created_at: datetime
