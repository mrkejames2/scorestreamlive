#!/usr/bin/env python3
"""M21-B source-aware integration. Run from the repository root after extracting."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
def patch(rel, old, new):
    p=root/rel
    content=p.read_text()
    if new in content: return
    if old not in content: raise RuntimeError(f'Integration anchor missing in {rel}: {old[:80]!r}')
    p.write_text(content.replace(old,new,1))

def append(rel, snippet):
    p=root/rel
    content=p.read_text()
    if snippet.strip() not in content:p.write_text(content.rstrip()+"\n\n"+snippet)

def run():
    patch('app/models/team.py', '    name: Mapped[str]', '    sport: Mapped[str] = mapped_column(String(20), nullable=False, default="soccer")\n\n    name: Mapped[str]')
    patch('app/models/game.py', '    name: Mapped[str]', '    sport: Mapped[str] = mapped_column(String(20), nullable=False, default="soccer")\n\n    name: Mapped[str]')
    patch('app/schemas/team.py', 'from pydantic import BaseModel, ConfigDict, Field', 'from pydantic import BaseModel, ConfigDict, Field\nfrom typing import Literal')
    patch('app/schemas/team.py', 'class TeamBase(BaseModel):', 'class TeamBase(BaseModel):')
    patch('app/schemas/team.py', '    name: str = Field(', '    sport: Literal["soccer", "futsal"] = "soccer"\n    name: str = Field(')
    patch('app/schemas/team.py', 'class TeamUpdate(BaseModel):', 'class TeamUpdate(BaseModel):')
    patch('app/schemas/team.py', 'class TeamResponse(TeamBase):', 'class TeamResponse(TeamBase):')
    patch('app/schemas/game.py', 'from pydantic import BaseModel, ConfigDict, Field', 'from pydantic import BaseModel, ConfigDict, Field\nfrom typing import Literal')
    patch('app/schemas/game.py', 'class GameBase(BaseModel):', 'class GameBase(BaseModel):')
    patch('app/schemas/game.py', '    name: str = Field(', '    sport: Literal["soccer", "futsal"] = "soccer"\n    name: str = Field(')
    patch('app/services/team_service.py', '        name=data.name,', '        sport=data.sport,\n        name=data.name,')
    patch('app/services/game_service.py', '        name=data.name,', '        sport=data.sport,\n        name=data.name,')
    patch('app/services/game_service.py', '    away_team_id: Optional[uuid.UUID],\n) -> None:', '    away_team_id: Optional[uuid.UUID],\n    sport: str = "soccer",\n) -> None:')
    patch('app/services/game_service.py', 'if not team or team.club_id != club_id or team.archived_at is not None:', 'if not team or team.club_id != club_id or team.archived_at is not None or team.sport != sport:')
    p=root/'app/services/game_service.py'; c=p.read_text(); anchor='if not team or team.club_id != club_id or team.archived_at is not None:'; c=c.replace(anchor,anchor[:-1]+' or team.sport != sport:'); p.write_text(c)
    patch('app/services/game_service.py', 'data.home_team_id, data.away_team_id)', 'data.home_team_id, data.away_team_id, data.sport)')
    patch('app/services/game_service.py', 'final_home, final_away)', 'final_home, final_away, game.sport)')
    patch('app/services/game_service.py', '        "name": game.name,', '        "name": game.name,\n        "sport": game.sport,')
    patch('app/services/team_service.py', '        "name": team.name,', '        "name": team.name,\n        "sport": team.sport,')
    patch('app/api/games.py', '    archived: bool = Query(default=False),', '    archived: bool = Query(default=False),\n    sport: Optional[str] = Query(default=None, pattern="^(soccer|futsal)$"),')
    patch('app/api/games.py', '    if limit is not None:\n        return games[:limit]', '    if sport is not None:\n        games = [game for game in games if game.sport == sport]\n\n    if limit is not None:\n        return games[:limit]')
    patch('app/api/teams.py', '    archived: bool = Query(default=False),', '    archived: bool = Query(default=False),\n    sport: str = Query(default="soccer", pattern="^(soccer|futsal)$"),')
    patch('app/api/teams.py', '    if visible_ids is None:\n        return teams', '    teams = [team for team in teams if team.sport == sport]\n\n    if visible_ids is None:\n        return teams')
    # Preserve the existing soccer dashboard by filtering its game-list fetch.
    p=root/'static/js/games/index.js'
    content=p.read_text()
    if 'api("/api/games?sport=soccer")' not in content:
        content=content.replace('api("/api/games")', 'api("/api/games?sport=soccer")')
        p.write_text(content)
    # Futsal page is registered through the existing M21-A web router.
    append('app/web/games.py', '''\n@router.get("/futsal/games", response_class=HTMLResponse)\nasync def futsal_games(request: Request) -> HTMLResponse:\n    return templates.TemplateResponse(request=request, name="sports/futsal_games.html", context={"page_title": "Futsal Games"})\n''')
    print('M21-B integration complete. Review git diff before migration.')
if __name__=='__main__':
    try:run()
    except Exception as exc:print(f'ERROR: {exc}',file=sys.stderr);sys.exit(1)
