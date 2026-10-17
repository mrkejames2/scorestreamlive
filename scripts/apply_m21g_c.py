#!/usr/bin/env python3
"""M21-G-C sport-aware teams and rosters; guarded, repeatable local installer."""
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[1]
TAG='M21-G-C'

def patch(path, before, after):
    f=ROOT/path
    if not f.exists(): raise SystemExit(f'Missing prerequisite: {path}')
    s=f.read_text()
    if after in s:
        print('Already patched:',path);return
    if before not in s: raise SystemExit(f'Unexpected baseline in {path}: expected anchor not found')
    backup=f.with_name(f.name+'.before-m21gc')
    if not backup.exists(): shutil.copy2(f,backup)
    f.write_text(s.replace(before,after,1))
    print('Patched:',path)

route='app/web/sport_routes_m21ga.py'
patch(route,"@router.get('/soccer/teams', response_class=HTMLResponse, include_in_schema=False)","@router.get('/soccer/teams', response_class=HTMLResponse, include_in_schema=False)") if False else None
patch(route,"context={'page_title':'Soccer Teams','milestone':'M21-G-A'}","context={'page_title':'Soccer Teams','milestone':'M21-G-C','sport':'soccer'}")
patch(route,"    # Until M21-G-C ships a sport-aware team index, send operators to\n    # the existing Futsal team creation/selection panel. Never show Soccer teams.\n    return RedirectResponse('/futsal/games#team-form', status_code=303)","    return templates.TemplateResponse(request=request, name='teams/index.html', context={'page_title':'Futsal Teams','milestone':'M21-G-C','sport':'futsal'})")
patch(route,"async def futsal_teams(user: User = Depends(require_current_user)):","async def futsal_teams(request: Request, user: User = Depends(require_current_user)):")
patch(route,"'page_title':'Soccer Team','milestone':'M21-G-A','team_id':str(team_id)","'page_title':'Soccer Team','milestone':'M21-G-C','sport':'soccer','team_id':str(team_id)")
patch(route,"'page_title':'Futsal Team','milestone':'M21-G-A','team_id':str(team_id)","'page_title':'Futsal Team','milestone':'M21-G-C','sport':'futsal','team_id':str(team_id)")
# Preserve legacy /teams URLs and behavior; canonical pages receive sport context.
idx='templates/teams/index.html'
patch(idx,'<body>','<body data-sport="{{ sport | default(\'soccer\') }}">')
patch(idx,'<title>ScoreStreamLive — Teams</title>','<title>ScoreStreamLive — {{ (sport | default(\'soccer\')) | capitalize }} Teams</title>')
patch(idx,'<link rel="stylesheet" href="/static/css/teams.css">','<link rel="stylesheet" href="/static/css/teams.css">\n  <link rel="stylesheet" href="/static/css/teams-m21gc.css?v=m21gc1">')
patch(idx,'<main class="teams-shell">','<div class="m21gc-layout"><button class="m21gc-menu" type="button" aria-expanded="false" aria-controls="m21gc-sidebar">☰ Menu</button><aside id="m21gc-sidebar" class="m21gc-sidebar" aria-label="Sport navigation"><a class="m21gc-brand" href="/sports/home">SCORESTREAMLIVE</a><div class="m21gc-label">CURRENT SPORT</div><strong class="m21gc-sport">{{ (sport | default(\'soccer\')) | capitalize }}</strong><nav><a href="/{{ sport | default(\'soccer\') }}/games">Games</a><a class="current" aria-current="page" href="/{{ sport | default(\'soccer\') }}/teams">Teams</a><a href="/sports">Switch Sport</a></nav></aside><div class="m21gc-content"><main class="teams-shell">')
patch(idx,'</main>\n\n<template id="team-card-template">','</main></div></div>\n\n<template id="team-card-template">')
patch(idx,'<h1>Teams</h1>','<h1>{{ (sport | default(\'soccer\')) | capitalize }} Teams</h1>')
patch(idx,'href="/games">Games</a>','href="/{{ sport | default(\'soccer\') }}/games">Games</a>')
patch(idx,'<script type="module" src="/static/js/teams/index.js"></script>','<script type="module" src="/static/js/teams/index.js"></script>\n<script src="/static/js/teams/teams-m21gc.js?v=m21gc1" defer></script>')
# Avoid account nav duplicated above sidebar on canonical pages; legacy remains unchanged.
patch(idx,'<script src="/static/js/account-nav.js?v=m18g3-branding1"></script>','{% if sport is not defined %}<script src="/static/js/account-nav.js?v=m18g3-branding1"></script>{% endif %}')
js='static/js/teams/index.js'
patch(js,'n.querySelector(".view-team-link").href=`/teams/${t.id}`;','n.querySelector(".view-team-link").href=`/${document.body.dataset.sport||"soccer"}/teams/${t.id}`;')
patch(js,'const data=await json("/api/teams");','const data=await json(`/api/teams?sport=${encodeURIComponent(document.body.dataset.sport||"soccer")}`);')
patch(js,'const payload={name:nameInput.value.trim(),short_name:shortInput.value.trim()||null,primary_color:primaryInput.value.trim()||null,secondary_color:secondaryInput.value.trim()||null};','const payload={name:nameInput.value.trim(),short_name:shortInput.value.trim()||null,primary_color:primaryInput.value.trim()||null,secondary_color:secondaryInput.value.trim()||null};\n    if(!editingTeam)payload.sport=document.body.dataset.sport||"soccer";')
detail='templates/teams/detail.html'
patch(detail,'<body>','<body data-sport="{{ sport | default(\'soccer\') }}">')
patch(detail,'<link rel="stylesheet" href="/static/css/team-detail.css">','<link rel="stylesheet" href="/static/css/team-detail.css">\n  <link rel="stylesheet" href="/static/css/teams-m21gc.css?v=m21gc1">')
patch(detail,'<main class="detail-shell" data-team-id="{{ team_id }}">','<div class="m21gc-layout"><button class="m21gc-menu" type="button" aria-expanded="false" aria-controls="m21gc-sidebar">☰ Menu</button><aside id="m21gc-sidebar" class="m21gc-sidebar" aria-label="Sport navigation"><a class="m21gc-brand" href="/sports/home">SCORESTREAMLIVE</a><div class="m21gc-label">CURRENT SPORT</div><strong class="m21gc-sport">{{ (sport | default(\'soccer\')) | capitalize }}</strong><nav><a href="/{{ sport | default(\'soccer\') }}/games">Games</a><a class="current" href="/{{ sport | default(\'soccer\') }}/teams">Teams</a><a href="/sports">Switch Sport</a></nav></aside><div class="m21gc-content"><main class="detail-shell" data-team-id="{{ team_id }}">')
patch(detail,'href="/teams">← Teams</a>','href="/{{ sport | default(\'soccer\') }}/teams">← {{ (sport | default(\'soccer\')) | capitalize }} Teams</a>')
patch(detail,'</main>','</main></div></div>')
patch(detail,'<script src="/static/js/account-nav.js?v=m18g3-branding1"></script>','{% if sport is not defined %}<script src="/static/js/account-nav.js?v=m18g3-branding1"></script>{% endif %}')
patch(detail,'</body>','<script src="/static/js/teams/teams-m21gc.js?v=m21gc1" defer></script>\n</body>')
# Add roster link on each Futsal match card when a managed team is assigned.
gamesjs='static/js/sports/futsal_games_m21gb.js'
patch(gamesjs,'<div class="match-actions"><a class="button button-primary" href="${control}">Control Center</a>', '<div class="match-actions">${g.my_team_id?`<a class="button button-secondary" href="/futsal/teams/${encodeURIComponent(g.my_team_id)}?game=${encodeURIComponent(g.id)}">My Team Roster</a>`:""}<a class="button button-primary" href="${control}">Control Center</a>')
# Detail return link only for same-origin UUID-shaped game identifier, validated on server route.
shutil.copy2(ROOT/'static/css/teams-m21gc.css',ROOT/'static/css/teams-m21gc.css') if False else None
print('M21-G-C installed. No migration. Review diff and run local tests.')
