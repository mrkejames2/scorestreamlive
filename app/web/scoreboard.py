import uuid
from pathlib import Path
from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
router = APIRouter(tags=["scoreboard"])
BASE_DIR = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))
@router.get("/scoreboard/games/{game_id}", response_class=HTMLResponse, include_in_schema=False)
async def scoreboard_page(request: Request, game_id: uuid.UUID):
    return templates.TemplateResponse(request=request, name="scoreboard/game.html", context={"game_id": str(game_id)})
