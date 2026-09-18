from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field
ALLOWED_INTERVALS={5,10,15,20,30,45,60}
class SponsorPresentationUpdate(BaseModel):
    action:str=Field(pattern="^(previous|next|set_visible|set_rotation|set_interval)$")
    visible:bool|None=None
    rotation_enabled:bool|None=None
    rotation_interval_seconds:int|None=None
    expected_version:int
class SponsorPresentationResponse(BaseModel):
    game_id:UUID
    current_sponsor_id:UUID|None=None
    visible:bool
    rotation_enabled:bool
    rotation_interval_seconds:int
    version:int
    updated_at:datetime
    sponsors:list[dict]
