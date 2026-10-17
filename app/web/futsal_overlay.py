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
