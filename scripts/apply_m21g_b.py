#!/usr/bin/env python3
"""M21-G-B: fail-closed, idempotent Futsal Games dashboard installer."""
from pathlib import Path
import shutil, sys
root=Path(__file__).resolve().parents[1]
target=root/'templates/sports/futsal_games.html'
source=root/'templates/sports/futsal_games_m21gb.html'
checks=[
 root/'app/web/sport_routes_m21ga.py',
 root/'static/js/sports/futsal_games_m21f_r4.js',
 root/'static/js/sports/futsal_games_m21gb.js',
 root/'static/css/futsal-games-m21gb.css',
 target,source,
]
missing=[str(p.relative_to(root)) for p in checks if not p.is_file()]
if missing:sys.exit('M21-G-B prerequisites missing (install M21-G-A and M21-F R4 first): '+', '.join(missing))
current=target.read_text()
desired=source.read_text()
if current==desired:
 print('M21-G-B already installed; no changes.')
 sys.exit(0)
if 'id="game-form"' not in current or 'id="games"' not in current or 'futsal_games_m21f_r4.js' not in current:
 sys.exit('Unexpected Futsal Games template. R4 hooks missing; refusing to overwrite.')
if 'futsal-games-m21gb.css' in current:
 sys.exit('M21-G-B template differs from expected output. Refusing to overwrite local customizations.')
backup=target.with_suffix('.html.before-m21gb')
if backup.exists():
 sys.exit('Backup already exists but target differs. Review '+str(backup)+' before retrying.')
shutil.copy2(target,backup)
target.write_text(desired)
print('Installed Futsal Games dashboard; original backed up to '+str(backup.relative_to(root)))
print('No database migration. M21-F R4 My Team workflow retained.')
