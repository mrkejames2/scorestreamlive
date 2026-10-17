#!/usr/bin/env python3
"""M21-F revision 2 installer. Run from repository root after M21-F."""
from pathlib import Path
import ast
root=Path.cwd()
for required in ('app/main.py','app/api/futsal_rules.py','app/api/futsal_clock.py','templates/sports/futsal_controls.html','static/js/sports/futsal_controls_m21e.js'):
    if not (root/required).exists():raise SystemExit(f'Missing {required}; install M21-E and M21-F first')
p=root/'app/api/futsal_rules.py';s=p.read_text();old="'period_seconds':cfg.period_seconds if cfg else None}";new="'period_seconds':cfg.period_seconds if cfg else None, 'updated_at':cfg.updated_at.isoformat() if cfg and cfg.updated_at else None}"
if new not in s:
    if old not in s:raise SystemExit('Unexpected futsal_rules.py; no API modification made')
    s=s.replace(old,new,1);ast.parse(s);p.write_text(s);print('Updated Futsal period API with transition timestamp')
else:print('Period API already updated')
print('M21-F-R2 installed. No schema migration. Restart application.')
