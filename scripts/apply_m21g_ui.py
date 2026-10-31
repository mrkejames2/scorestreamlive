#!/usr/bin/env python3
"""Idempotent, guarded Futsal shared navigation installer; no database changes."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
NAV='''<aside class="m21ui-sidebar" id="m21ui-sidebar" aria-label="Futsal navigation">
<a class="m21ui-brand" href="/sports/home">SCORE<span>STREAMLIVE</span></a>
<div class="m21ui-label">CURRENT SPORT</div><div class="m21ui-sport">⚽ Futsal</div>
<nav class="m21ui-nav" aria-label="Main navigation">
<a href="/futsal/games" DATA_GAMES>▦ <span>Games</span></a>
<a href="/futsal/teams" DATA_TEAMS>♟ <span>Teams &amp; Rosters</span></a>
<a href="/account/sponsors?from=futsal" DATA_SPONSORS>▣ <span>Sponsor Library</span></a>
<a href="/account/branding?from=futsal" DATA_BRANDING>◈ <span>Club Branding</span></a>
<div class="m21ui-divider" role="separator"></div>
<a href="/account?from=futsal" DATA_ACCOUNT>⚙ <span>Account Settings</span></a>
<a href="/account/billing?from=futsal" DATA_BILLING>▤ <span>Billing</span></a>
</nav><div class="m21ui-switch"><a href="/sports">⇄ <span>Switch Sport</span></a></div></aside>'''
PAGES={
 'templates/sports/futsal_games.html':'GAMES',
 'templates/teams/index.html':'TEAMS',
 'templates/teams/detail.html':'TEAMS',
 'templates/sports/futsal_controls.html':'GAMES',
 'templates/account/branding.html':'BRANDING',
 'templates/account/sponsors.html':'SPONSORS',
 'templates/account/index.html':'ACCOUNT',
 'templates/account/billing.html':'BILLING',
}
CSS='<link rel="stylesheet" href="/static/css/m21gui-shell.css?v=m21gui1">'
JS='<script src="/static/js/m21gui-shell.js?v=m21gui1" defer></script>'
for name,active in PAGES.items():
 p=ROOT/name
 if not p.exists():
  raise SystemExit(f'Missing required file: {name}')
 original=p.read_text()
 if 'm21ui-shell' in original:
  print('Already applied:',name);continue
 nav=NAV.replace('DATA_'+active,'aria-current="page"')
 nav=re.sub(r' DATA_(?:GAMES|TEAMS|SPONSORS|BRANDING|ACCOUNT|BILLING)','',nav)
 conditional=name.startswith('templates/account/') or name.startswith('templates/teams/')
 if name.startswith('templates/account/'):
  guard="request.query_params.get('from') == 'futsal'"
 elif name.startswith('templates/teams/'):
  guard="(sport | default('soccer')) == 'futsal'"
 else:guard=None
 # In account pages, keep the legacy header for Soccer and other non-Futsal contexts.
 # Wrap all existing body content inside the new shell when Futsal context is requested.
 opening='<div class="m21ui-shell"><button class="m21ui-toggle" type="button" aria-expanded="false" aria-controls="m21ui-sidebar">☰ Menu</button>'+nav+'<div class="m21ui-content">'
 if guard:
  opening='{% if '+guard+' %}'+opening+'{% endif %}'
  closing='{% if '+guard+' %}</div></div>{% endif %}'
 else:closing='</div></div>'
 # Place wrapper immediately after opening body tag, preserving all preexisting scripts and DOM IDs.
 body=re.search(r'<body\b[^>]*>',original,re.I)
 if not body:raise SystemExit('Missing body: '+name)
 modified=original[:body.end()]+opening+original[body.end():]
 end=re.search(r'</body\s*>',modified,re.I)
 if not end:raise SystemExit('Missing closing body: '+name)
 modified=modified[:end.start()]+closing+modified[end.start():]
 head_end=re.search(r'</head\s*>',modified,re.I)
 if not head_end:raise SystemExit('Missing head: '+name)
 modified=modified[:head_end.start()]+CSS+modified[head_end.start():]
 end=re.search(r'</body\s*>',modified,re.I)
 modified=modified[:end.start()]+JS+modified[end.start():]
 # Existing sidebar is hidden by CSS only, keeping existing JS and DOM contracts intact.
 # In Futsal context the legacy top nav is hidden; other contexts remain untouched.
 p.write_text(modified)
 print('Updated:',name)
print('M21-G-UI installed. Review git diff, test locally, do not merge to main yet.')
