"""M21-E public period metadata for the Futsal overlay, entitlement gated."""
import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import deny_not_found
from app.database import get_session
from app.models.game import Game
from app.models.futsal_clock_config import FutsalClockConfig
from app.services.entitlement_service import BROADCAST_OVERLAY, effective_club_has_entitlement

router = APIRouter(tags=['futsal-rules'])

@router.get('/api/public/futsal/games/{game_id}/period', include_in_schema=False)
async def futsal_public_period(game_id: uuid.UUID, db: AsyncSession = Depends(get_session)):
    game = await db.get(Game, game_id)
    if not game or game.sport != 'futsal' or not await effective_club_has_entitlement(db, game.club_id, BROADCAST_OVERLAY):
        deny_not_found('Futsal game')
    cfg = await db.get(FutsalClockConfig, game_id)
    return {'period': cfg.period if cfg else None, 'clock_policy': cfg.clock_policy if cfg else None, 'period_seconds':cfg.period_seconds if cfg else None}
