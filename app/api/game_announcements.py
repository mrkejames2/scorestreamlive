import logging
import uuid
from fastapi import APIRouter, Depends, Request, HTTPException
from fastapi.encoders import jsonable_encoder
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import can_operate_game, deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.game import Game
from app.models.user import User
from app.schemas.game_announcement import AnnouncementListIn, AnnouncementCommandIn
from app.services.game_announcement_service import get_state, save_list, command
from app.sockets import sio, game_room

router = APIRouter(tags=["game-announcements"])
logger = logging.getLogger("app")

async def game_for(db, game_id):
    game = await db.get(Game, game_id)
    if game is None:
        raise HTTPException(404, "Game not found")
    return game

async def operator(db, game_id, user):
    game = await game_for(db, game_id)
    if not await can_operate_game(db, user, game):
        deny_not_found("Game")
    return game

async def publish(game_id, state):
    try:
        await sio.emit("announcement:presentation_updated", jsonable_encoder(state), room=game_room(game_id, "overlay"))
    except Exception:
        logger.exception("HF11 announcement emit failed", extra={"game_id": str(game_id)})

@router.get("/api/public/games/{game_id}/announcements")
async def public_state(game_id: uuid.UUID, db: AsyncSession = Depends(get_session)):
    await game_for(db, game_id)
    return await get_state(db, game_id)

@router.get("/api/games/{game_id}/announcements")
async def operator_state(game_id: uuid.UUID, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    await operator(db, game_id, user)
    return await get_state(db, game_id)

@router.put("/api/games/{game_id}/announcements")
async def replace_list(game_id: uuid.UUID, data: AnnouncementListIn, request: Request, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    require_same_origin_mutation(request)
    game = await operator(db, game_id, user)
    if game.archived_at is not None:
        raise HTTPException(409, "Archived Games are read-only")
    result = await save_list(db, game_id, data)
    await publish(game_id, result)
    return result

@router.post("/api/games/{game_id}/announcements/command")
async def command_state(game_id: uuid.UUID, data: AnnouncementCommandIn, request: Request, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    require_same_origin_mutation(request)
    game = await operator(db, game_id, user)
    if game.archived_at is not None:
        raise HTTPException(409, "Archived Games are read-only")
    result = await command(db, game_id, data)
    await publish(game_id, result)
    return result
