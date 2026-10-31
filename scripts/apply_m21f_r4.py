#!/usr/bin/env python3
"""M21-F R4 fail-closed root-relative installer. Requires M21-F R3."""
from pathlib import Path
import ast, sys
root=Path.cwd()
required=[
 'app/models/game.py','app/schemas/game.py','app/services/game_service.py',
 'templates/sports/futsal_games.html','templates/sports/futsal_controls.html',
 'static/js/sports/futsal_controls_m21e.js',
 'static/js/sports/futsal_roster_m21f_r3.js',
 'alembic/versions/20261016_0042_m21f_futsal_goal_clock.py',
 'alembic/versions/20261016_0043_m21f_my_team.py',
]
for path in required:
 if not (root/path).is_file():sys.exit(f'Missing {path}. Extract R4 ZIP and ensure R3 was installed. No changes made.')
changes={}
def edit(path,old,new):
 s=changes.get(path,(root/path).read_text())
 if new in s:return
 if old not in s:sys.exit(f'Unexpected {path}: anchor not found {old[:75]!r}. No changes made.')
 changes[path]=s.replace(old,new,1)

edit('app/models/game.py',
 '    home_team_id: Mapped[Optional[uuid.UUID]]',
 '    # Explicit managed roster; only populated for futsal games.\n    my_team_id: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("teams.id", ondelete="RESTRICT"), nullable=True)\n\n    home_team_id: Mapped[Optional[uuid.UUID]]')
edit('app/schemas/game.py',
 'class GameCreate(GameBase):\n    """Fields required to create a Game."""\n\n    pass',
 'class GameCreate(GameBase):\n    """Fields required to create a Game."""\n\n    my_team_id: Optional[UUID] = None')
edit('app/schemas/game.py',
 'class GameUpdate(BaseModel):\n    """Fields allowed when updating a Game."""',
 'class GameUpdate(BaseModel):\n    """Fields allowed when updating a Game."""\n\n    my_team_id: Optional[UUID] = None')
edit('app/schemas/game.py',
 'class GameResponse(GameBase):\n    """Full Game representation returned by the API."""',
 'class GameResponse(GameBase):\n    """Full Game representation returned by the API."""\n\n    my_team_id: Optional[UUID] = None')
edit('app/services/game_service.py',
 '        "sport": game.sport,',
 '        "sport": game.sport,\n        "my_team_id": str(game.my_team_id) if game.my_team_id else None,')
edit('app/services/game_service.py',
 '    now = datetime.now(timezone.utc)\n    game = Game(',
 '''    # M21-F R4: My Team is a participant, not a separate opponent roster.
    if data.sport == "futsal":
        if data.my_team_id is None or data.my_team_id not in (data.home_team_id, data.away_team_id):
            raise ValueError("Select My Team as Home or Away for Futsal")
    elif data.my_team_id is not None:
        raise ValueError("My Team selection is only supported for Futsal")

    now = datetime.now(timezone.utc)
    game = Game(''')
edit('app/services/game_service.py',
 '        sport=data.sport,\n        name=data.name,',
 '        sport=data.sport,\n        my_team_id=data.my_team_id if data.sport == "futsal" else None,\n        name=data.name,')
edit('app/services/game_service.py',
 '    await _validate_game_teams(db, game.club_id, final_home, final_away, game.sport)\n\n    if data.name is not None:',
 '''    await _validate_game_teams(db, game.club_id, final_home, final_away, game.sport)
    # Preserve explicit selection when editing participants; allow assigning
    # My Team to older Futsal games that predate this revision.
    final_my_team = data.my_team_id if data.my_team_id is not None else game.my_team_id
    if game.sport == "futsal":
        if final_my_team is not None and final_my_team not in (final_home, final_away):
            raise ValueError("My Team must be Home or Away in this Futsal game")
    elif data.my_team_id is not None:
        raise ValueError("My Team selection is only supported for Futsal")

    if data.name is not None:''')
edit('app/services/game_service.py',
 '    if data.name is not None:\n        game.name = data.name',
 '    if data.my_team_id is not None and game.sport == "futsal":\n        game.my_team_id = data.my_team_id\n    if data.name is not None:\n        game.name = data.name')
# Replace R3 page script additions with a single additional script and styling.
p='templates/sports/futsal_games.html'
s=(root/p).read_text()
marker='<script src="/static/js/sports/futsal_games_m21f_r4.js?v=m21fr4" defer></script>'
if marker not in s:
 if '</body>' not in s:sys.exit('Unexpected Futsal Games template; no changes made.')
 s=s.replace('</body>',marker+'</body>',1)
 s=s.replace('</head>','<style>.m21f-r4-form{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:12px;margin:12px 0}.m21f-r4-form label{display:grid;gap:6px}.m21f-r4-form select,.m21f-r4-form button{min-height:46px;width:100%;font-size:16px}.r4-assign{background:#19263b;padding:16px;border-radius:10px;margin:14px 0}[hidden]{display:none!important}@media(max-width:600px){main{padding:14px}.m21f-r4-form{grid-template-columns:minmax(0,1fr)}} </style></head>',1)
 changes[p]=s
# R3 scripts are replaced, not stacked, to avoid loading two independent roster refreshers.
p='templates/sports/futsal_controls.html'
s=(root/p).read_text()
for old,new in [
 ('/static/js/sports/futsal_roster_m21f_r3.js','/static/js/sports/futsal_roster_m21f_r4.js'),
 ('/static/js/sports/futsal_corrections_m21f.js','/static/js/sports/futsal_corrections_m21f_r4.js')]:
 if new not in s:
  if old not in s:sys.exit(f'Unexpected {p}: missing {old}. No changes made.')
  s=s.replace(old,new,1)
if 'm21fr4' not in s:s=s.replace('m21fr3','m21fr4')
if 'm21f-r4-hide' not in s:s=s.replace('</head>','<style id="m21f-r4-hide">[hidden]{display:none!important}</style></head>',1)
changes[p]=s
# R3 goal command already reads selected scorer. R4 forces opponent to null
# via disabled/hidden select and resets its value; enforce that at the command.
p='static/js/sports/futsal_controls_m21e.js'
s=(root/p).read_text()
old='player_id:(document.getElementById(`${b.dataset.goal}-scorer`)?.value||null),event_type:'
new='player_id:(document.getElementById(`${b.dataset.goal}-scorer`)?.disabled?null:(document.getElementById(`${b.dataset.goal}-scorer`)?.value||null)),event_type:'
if new not in s:
 if old not in s:sys.exit(f'Unexpected {p}: R3 goal command not found. No changes made.')
 changes[p]=s.replace(old,new,1)
for path,content in changes.items():
 if path.endswith('.py'):ast.parse(content,filename=path)
for path,content in changes.items():
 (root/path).write_text(content)
 print('Updated',path)
print('M21-F R4 installed. Apply Alembic 20261016_0043 before starting the app.')
