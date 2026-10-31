"""M21-C futsal-only countdown clock controls. No writes per tick."""
import uuid
from datetime import datetime, timezone
from typing import Literal
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import can_operate_game, can_view_game, deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.game import Game
from app.models.user import User
from app.models.futsal_clock_config import FutsalClockConfig
from app.schemas.game_clock import GameClockCreate, GameClockCommand, GameClockUpdate
from app.services.game_clock_service import (
    get_clock, create_clock, start_clock, pause_clock, resume_clock, reset_clock,
    update_clock_configuration, serialize_clock_state, ClockConflictError, ClockNotFoundError,
)

router = APIRouter(prefix='/api/futsal/games', tags=['futsal-clock'])

class Configure(BaseModel):
    period_seconds: int = Field(default=1200, ge=60, le=3600)
    clock_policy: Literal['stop_clock', 'running_clock'] = 'stop_clock'

class Command(BaseModel):
    expected_version: int = Field(ge=1)

async def access(db, user, game_id, operate=False):
    game = await db.get(Game, game_id)
    if not game or game.sport != 'futsal':
        deny_not_found('Futsal game')
    permitted = await (can_operate_game(db, user, game) if operate else can_view_game(db, user, game))
    if not permitted:
        deny_not_found('Futsal game')
    if operate and game.archived_at is not None:
        raise HTTPException(409, 'Archived games are read-only')
    return game

def state(clock, cfg):
    payload = serialize_clock_state(clock)
    payload.update(period=cfg.period, clock_policy=cfg.clock_policy, period_seconds=cfg.period_seconds)
    return payload

async def existing(db, game_id):
    cfg = await db.get(FutsalClockConfig, game_id)
    clock = await get_clock(db, game_id)
    if cfg is None or clock is None:
        raise HTTPException(404, 'Futsal clock is not initialized')
    return clock, cfg

@router.get('/{game_id}/clock')
async def read(game_id: uuid.UUID, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    await access(db, user, game_id)
    clock, cfg = await existing(db, game_id)
    return state(clock, cfg)

@router.post('/{game_id}/clock')
async def initialize(game_id: uuid.UUID, data: Configure, request: Request, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    require_same_origin_mutation(request)
    await access(db, user, game_id, True)
    if await get_clock(db, game_id):
        raise HTTPException(409, 'Game clock already initialized')
    try:
        clock = await create_clock(db, game_id, GameClockCreate(mode='count_down', duration_seconds=data.period_seconds))
    except (ClockConflictError, ClockNotFoundError) as exc:
        raise HTTPException(409, str(exc))
    cfg = FutsalClockConfig(game_id=game_id, period=1, clock_policy=data.clock_policy,
                            period_seconds=data.period_seconds, updated_at=datetime.now(timezone.utc))
    db.add(cfg)
    await db.commit()
    return state(clock, cfg)

@router.post('/{game_id}/clock/{action}')
async def command(game_id: uuid.UUID, action: Literal['start','pause','resume','reset','next-period'],
                  data: Command, request: Request, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    require_same_origin_mutation(request)
    await access(db, user, game_id, True)
    clock, cfg = await existing(db, game_id)
    if clock.mode != 'count_down':
        raise HTTPException(409, 'Futsal requires a countdown clock')
    if action == 'next-period':
        if cfg.period != 1 or clock.status == 'running':
            raise HTTPException(409, 'Next period requires a stopped or paused first half')
        if clock.version != data.expected_version:
            raise HTTPException(409, 'Clock version conflict; refresh')
        # Reset first, then advance period. Both changes are persisted before responding.
        try:
            clock = await reset_clock(db, game_id, data.expected_version)
        except ClockConflictError as exc:
            raise HTTPException(409, str(exc))
        cfg.period = 2
        cfg.updated_at = datetime.now(timezone.utc)
        await db.commit()
        return state(clock, cfg)
    operations = {'start':start_clock, 'pause':pause_clock, 'resume':resume_clock, 'reset':reset_clock}
    try:
        clock = await operations[action](db, game_id, data.expected_version)
    except (ClockConflictError, ClockNotFoundError) as exc:
        raise HTTPException(409, str(exc))
    return state(clock, cfg)
