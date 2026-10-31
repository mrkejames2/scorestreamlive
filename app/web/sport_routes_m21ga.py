"""M21-G-A: canonical browser-facing sport routes; legacy URLs remain untouched.

Explicit sport checks prevent cross-sport UUID access through canonical routes.
This module is deliberately additive and has no database migration.
"""
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import can_operate_game, can_view_game, deny_not_found
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.game import Game
from app.models.team import Team
from app.models.user import User

router = APIRouter(tags=['sport-pages'])
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parents[2] / 'templates'))


async def _game(db: AsyncSession, game_id: UUID, sport: str, user: User | None = None, operate: bool = False) -> Game:
    game = await db.get(Game, game_id)
    if not game or game.sport != sport or game.archived_at is not None:
        deny_not_found('Game')
    if user is not None:
        allowed = await (can_operate_game(db, user, game) if operate else can_view_game(db, user, game))
        if not allowed:
            deny_not_found('Game')
    return game


async def _team(db: AsyncSession, team_id: UUID, sport: str, user: User) -> Team:
    team = await db.get(Team, team_id)
    if not team or team.sport != sport or team.archived_at is not None or not user.club_id or team.club_id != user.club_id:
        deny_not_found('Team')
    return team


@router.get('/soccer/games', response_class=HTMLResponse, include_in_schema=False)
async def soccer_games(request: Request, user: User = Depends(require_current_user)):
    # Render the existing Soccer dashboard, not a duplicate implementation.
    return templates.TemplateResponse(request=request, name='games/index.html', context={'page_title':'Soccer Games','milestone':'M21-G-A'})


@router.get('/soccer/teams', response_class=HTMLResponse, include_in_schema=False)
async def soccer_teams(request: Request, user: User = Depends(require_current_user)):
    return templates.TemplateResponse(request=request, name='teams/index.html', context={'page_title':'Soccer Teams','milestone':'M21-G-C','sport':'soccer'})


@router.get('/soccer/teams/{team_id}', response_class=HTMLResponse, include_in_schema=False)
async def soccer_team_detail(request: Request, team_id: UUID, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    await _team(db, team_id, 'soccer', user)
    return templates.TemplateResponse(request=request, name='teams/detail.html', context={'page_title':'Soccer Team','milestone':'M21-G-C','sport':'soccer','team_id':str(team_id)})


@router.get('/futsal/teams', include_in_schema=False)
async def futsal_teams(request: Request, user: User = Depends(require_current_user)):
    return templates.TemplateResponse(request=request, name='teams/index.html', context={'page_title':'Futsal Teams','milestone':'M21-G-C','sport':'futsal'})


@router.get('/futsal/teams/{team_id}', response_class=HTMLResponse, include_in_schema=False)
async def futsal_team_detail(request: Request, team_id: UUID, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    await _team(db, team_id, 'futsal', user)
    return templates.TemplateResponse(request=request, name='teams/detail.html', context={'page_title':'Futsal Team','milestone':'M21-G-C','sport':'futsal','team_id':str(team_id)})


@router.get('/soccer/games/{game_id}', response_class=HTMLResponse, include_in_schema=False)
async def soccer_game_detail(request: Request, game_id: UUID, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    await _game(db, game_id, 'soccer', user)
    return templates.TemplateResponse(request=request, name='games/detail.html', context={'page_title':'Soccer Game','milestone':'M21-G-A','game_id':str(game_id)})


@router.get('/soccer/games/{game_id}/setup', response_class=HTMLResponse, include_in_schema=False)
async def soccer_game_setup(request: Request, game_id: UUID, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    await _game(db, game_id, 'soccer', user, operate=True)
    return templates.TemplateResponse(request=request, name='games/setup.html', context={'page_title':'Soccer Setup','milestone':'M21-G-A','game_id':str(game_id)})


@router.get('/soccer/games/{game_id}/control', response_class=HTMLResponse, include_in_schema=False)
async def soccer_control(request: Request, game_id: UUID, user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    await _game(db, game_id, 'soccer', user, operate=True)
    return templates.TemplateResponse(request=request, name='control/game.html', context={'game_id':str(game_id)})


@router.get('/soccer/games/{game_id}/overlay', response_class=HTMLResponse, include_in_schema=False)
async def soccer_overlay(request: Request, game_id: UUID, db: AsyncSession = Depends(get_session)):
    await _game(db, game_id, 'soccer')
    return templates.TemplateResponse(request=request, name='scoreboard/game.html', context={'game_id':str(game_id)})


@router.get('/futsal/scoreboard/games/{game_id}', response_class=HTMLResponse, include_in_schema=False)
async def futsal_venue_scoreboard(request: Request, game_id: UUID, db: AsyncSession = Depends(get_session)):
    await _game(db, game_id, 'futsal')
    return templates.TemplateResponse(request=request, name='sports/futsal_venue_scoreboard.html', context={'game_id':str(game_id)})


@router.get('/futsal/games/{game_id}/overlay', response_class=HTMLResponse, include_in_schema=False)
async def futsal_overlay(request: Request, game_id: UUID, db: AsyncSession = Depends(get_session)):
    await _game(db, game_id, 'futsal')
    return templates.TemplateResponse(request=request, name='sports/futsal_overlay.html', context={'game_id':str(game_id)})


@router.get('/soccer/games/{game_id}/stream', include_in_schema=False)
async def soccer_stream(game_id: UUID, db: AsyncSession = Depends(get_session)):
    await _game(db, game_id, 'soccer')
    # Preserve stable public stream URL and existing broadcast asset behavior.
    return RedirectResponse(f'/stream/games/{game_id}', status_code=307)


@router.get('/futsal/games/{game_id}/stream', include_in_schema=False)
async def futsal_stream(game_id: UUID, db: AsyncSession = Depends(get_session)):
    await _game(db, game_id, 'futsal')
    # Futsal does not yet have a unified stream-scene implementation.
    return RedirectResponse(f'/futsal/games/{game_id}/overlay', status_code=307)
