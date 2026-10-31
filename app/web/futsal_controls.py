"""M21-E isolated authenticated futsal operator screen."""
import uuid
from pathlib import Path
from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import can_operate_game, deny_not_found
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.game import Game
from app.models.user import User

router = APIRouter(tags=['futsal-controls'])
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parents[2] / 'templates'))

@router.get('/futsal/games/{game_id}/control', response_class=HTMLResponse, include_in_schema=False)
async def futsal_controls(request: Request, game_id: uuid.UUID, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    game = await db.get(Game, game_id)
    if not game or game.sport != 'futsal' or game.archived_at is not None or not await can_operate_game(db, user, game):
        deny_not_found('Futsal game')
    return templates.TemplateResponse(request=request, name='sports/futsal_controls.html', context={'game_id':str(game_id)})
