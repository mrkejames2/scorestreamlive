"""M21-C futsal clock controller page."""
import uuid
from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from app.auth.dependencies import require_current_user
from app.models.user import User
from pathlib import Path
from fastapi.templating import Jinja2Templates
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parents[2] / "templates"))

router = APIRouter()

@router.get('/futsal/games/{game_id}/clock', response_class=HTMLResponse)
async def futsal_clock_page(game_id: uuid.UUID, request: Request, current_user: User = Depends(require_current_user)):
    return templates.TemplateResponse(request=request, name='sports/futsal_clock.html', context={'game_id':str(game_id),'page_title':'Futsal Clock'})
