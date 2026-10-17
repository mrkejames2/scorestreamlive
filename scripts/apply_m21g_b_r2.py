#!/usr/bin/env python3
"""M21-G-B R2: isolated Futsal sidebar and contrast patch, idempotent."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
p=root/'templates/sports/futsal_games.html'
if not p.exists():sys.exit('Missing Futsal template')
s=p.read_text()
if 'id="new-game-panel"' not in s or 'futsal-games-m21gb.css' not in s:
 sys.exit('M21-G-B baseline not found; refusing to modify template')
if 'id="m21gb-sidebar"' in s:
 print('M21-G-B R2 already installed; no changes');sys.exit(0)
anchor='<main class="games-shell futsal-shell">'
if s.count(anchor)!=1 or s.count('</main>')!=1:sys.exit('Unexpected template structure; refusing patch')
sidebar='''<div class="m21gb-app-layout" id="m21gb-app-layout">
<button class="m21gb-menu-toggle" id="m21gb-menu-toggle" type="button" aria-expanded="false" aria-controls="m21gb-sidebar">☰ Menu</button>
<aside class="m21gb-sidebar" id="m21gb-sidebar" aria-label="Main navigation">
<a class="m21gb-brand" href="/sports/home">SCORE<span>STREAM</span>LIVE</a>
<div class="m21gb-sidebar-label">CURRENT SPORT</div>
<div class="m21gb-sport">⚽ Futsal</div>
<nav class="m21gb-side-links" aria-label="Futsal navigation">
<a class="is-current" aria-current="page" href="/futsal/games">▦ <span>Games</span></a>
<a href="/futsal/teams">♟ <span>Teams</span></a>
<a href="/sports">⇄ <span>Switch Sport</span></a>
</nav>
<div class="m21gb-sidebar-footer">ScoreStreamLive · Futsal</div>
</aside>
<div class="m21gb-content">'''
s=s.replace(anchor,sidebar+'\n'+anchor,1)
s=s.replace('</main>','</main>\n</div></div>',1)
s=s.replace('</head>','<link rel="stylesheet" href="/static/css/futsal-games-m21gb-r2.css?v=m21gbr2">\n</head>',1)
s=s.replace('</body>','<script src="/static/js/sports/futsal_sidebar_m21gb_r2.js?v=m21gbr2" defer></script>\n</body>',1)
backup=p.with_suffix('.html.before-m21gb-r2')
if backup.exists():sys.exit('Existing R2 backup found; refusing overwrite; review '+str(backup))
backup.write_text(p.read_text())
p.write_text(s)
print('M21-G-B R2 installed. Backup:',backup.relative_to(root))
