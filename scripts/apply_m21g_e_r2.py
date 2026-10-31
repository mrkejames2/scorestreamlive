#!/usr/bin/env python3
"""M21-G-E R2: additive, repeatable shared branding and sponsors integration."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def edit(name, old, new):
    p=ROOT/name
    text=p.read_text()
    if new in text:
        print('ALREADY',name);return
    if old not in text:
        raise SystemExit(f'Expected anchor missing in {name}; stopped without modifying that file')
    p.write_text(text.replace(old,new,1));print('UPDATED',name)

# Page route and public entitlement-aware branding projection, no schema changes.
p=ROOT/'app/web/futsal_overlay.py'
text=p.read_text()
block='''

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
'''
if 'async def futsal_public_club_branding(' not in text:
    p.write_text(text+block);print('UPDATED',p.relative_to(ROOT))
else:print('ALREADY',p.relative_to(ROOT))

edit('templates/sports/futsal_overlay.html',
     '</section><aside class="sponsor"',
     '</section><div id="m21ger2-club-brand" hidden><img alt="" hidden><span></span></div><aside class="sponsor"')
edit('templates/sports/futsal_overlay.html',
     '</head>',
     '<link rel="stylesheet" href="/static/css/futsal-branding-m21ger2.css?v=1"></head>')
edit('templates/sports/futsal_overlay.html',
     '</body></html>',
     '<script src="/static/js/sports/futsal_branding_m21ger2.js?v=1" defer></script></body></html>')
edit('templates/sports/futsal_controls.html',
     '<a href="/futsal/teams">Teams &amp; Rosters</a>',
     '<a href="/futsal/teams">Teams &amp; Rosters</a><a href="/futsal/games/{{ game_id }}/sponsors">Game Sponsors</a><a href="/account/branding">Club Branding</a>')
edit('templates/sports/futsal_controls.html',
     '<a href="/futsal/games#futsal-rosters">Teams &amp; Rosters</a>',
     '<a href="/futsal/teams">Teams &amp; Rosters</a><a href="/futsal/games/{{ game_id }}/sponsors">Game Sponsors</a>')
edit('templates/sports/futsal_games.html',
     '<a href="/sports">⇄ <span>Switch Sport</span></a>',
     '<a href="/sports">⇄ <span>Switch Sport</span></a><a href="/account/sponsors">▣ <span>Sponsor Library</span></a><a href="/account/branding">◈ <span>Club Branding</span></a>')
print('M21-G-E R2 installation complete. No database migration.')
