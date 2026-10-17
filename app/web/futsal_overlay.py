"""M21-D read-only futsal broadcast overlay, isolated from soccer routes."""
import uuid
from pathlib import Path
from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.models.game import Game
from app.auth.authorization import deny_not_found

router = APIRouter(tags=['futsal-overlay'])
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parents[2] / 'templates'))

@router.get('/futsal/overlay/games/{game_id}', response_class=HTMLResponse, include_in_schema=False)
async def futsal_overlay_page(request: Request, game_id: uuid.UUID, db: AsyncSession = Depends(get_session)):
    game = await db.get(Game, game_id)
    if game is None or game.sport != 'futsal':
        deny_not_found('Futsal game')
    return templates.TemplateResponse(request=request, name='sports/futsal_overlay.html', context={'game_id': str(game_id)})


# M21-G-E R2: share existing Club-level branding and sponsor records across sports.
@router.get('/api/public/futsal/games/{game_id}/club-branding', include_in_schema=False)
async def futsal_public_club_branding(game_id: uuid.UUID, db: AsyncSession = Depends(get_session)):
    from app.services.effective_branding_service import get_effective_club_branding
    game = await db.get(Game, game_id)
    if game is None or game.sport != 'futsal' or game.archived_at is not None or game.club_id is None:
        deny_not_found('Futsal game')
    return await get_effective_club_branding(db, game.club_id)


@router.get('/futsal/games/{game_id}/sponsors', response_class=HTMLResponse, include_in_schema=False)
async def futsal_game_sponsors_page(request: Request, game_id: uuid.UUID,
                                    user=Depends(__import__('app.auth.dependencies', fromlist=['require_current_user']).require_current_user),
                                    db: AsyncSession = Depends(get_session)):
    from app.auth.authorization import can_operate_game
    game = await db.get(Game, game_id)
    if game is None or game.sport != 'futsal' or game.archived_at is not None or not await can_operate_game(db, user, game):
        deny_not_found('Futsal game')
    return templates.TemplateResponse(request=request, name='sports/futsal_sponsors_m21ger2.html', context={'game_id': str(game_id)})
