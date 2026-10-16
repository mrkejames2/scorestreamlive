"""Game management and M21-A multi-sport navigation."""
from pathlib import Path
from fastapi import APIRouter, Depends, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.user import User

router = APIRouter()
PROJECT_ROOT = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(PROJECT_ROOT / "templates"))
SPORT_URLS = {"soccer": "/games", "futsal": "/futsal/games"}

@router.get("/sports/home")
async def sport_home(current_user: User = Depends(require_current_user)):
    """Redirect to last selected sport, defaulting legacy accounts to soccer."""
    sport = current_user.last_used_sport or "soccer"
    return RedirectResponse(SPORT_URLS.get(sport, "/games"), status_code=303)

@router.get("/sports", response_class=HTMLResponse)
async def sport_selection(request: Request, current_user: User = Depends(require_current_user)):
    return templates.TemplateResponse(request=request, name="sports/select.html", context={"page_title":"Choose sport", "current_sport":current_user.last_used_sport or "soccer"})

@router.post("/sports/switch")
async def switch_sport(request: Request, sport: str = Form(...), current_user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    require_same_origin_mutation(request)
    if sport not in SPORT_URLS:
        raise HTTPException(status_code=422, detail="Unsupported sport")
    # Update only the authenticated user, never a client-provided user ID.
    current_user.last_used_sport = sport
    await db.commit()
    return RedirectResponse(SPORT_URLS[sport], status_code=303)

@router.get("/sports/futsal", response_class=HTMLResponse)
async def futsal_home(request: Request, current_user: User = Depends(require_current_user)):
    """Safe M21-A landing page; game CRUD arrives in M21-B."""
    return templates.TemplateResponse(request=request, name="sports/futsal.html", context={"page_title":"Futsal", "current_sport":current_user.last_used_sport})

@router.get("/games", response_class=HTMLResponse)
async def game_management_home(request: Request) -> HTMLResponse:
    """Preserve soccer's existing game dashboard and add Switch Sport navigation."""
    response = templates.TemplateResponse(request=request, name="games/index.html", context={"page_title":"Games", "milestone":"M12-A"})
    # Existing games/index.html is a standalone template, not an inherited layout.
    # Add a small, accessible navigation element without rewriting its game JS.
    html = response.body.decode("utf-8")
    anchor = '<a href="/sports" class="button button-secondary" style="display:inline-flex;align-items:center;justify-content:center;text-decoration:none">Switch Sport</a>'
    if '</div>\n    </header>' in html:
        html = html.replace('</div>\n    </header>', anchor + '</div>\n    </header>', 1)
    else:
        # Fallback remains visible if template formatting changes.
        html = html.replace('</body>', '<nav style="padding:1rem"><a href="/sports">Switch Sport</a></nav></body>', 1)
    return HTMLResponse(content=html, status_code=response.status_code)


@router.get("/futsal/games", response_class=HTMLResponse)
async def futsal_games(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(request=request, name="sports/futsal_games.html", context={"page_title": "Futsal Games"})
