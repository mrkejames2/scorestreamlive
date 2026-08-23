"""Club response schemas for M15-B."""
import uuid
from pydantic import BaseModel, ConfigDict

class ClubResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    name: str
