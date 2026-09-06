#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
pass(){ echo "PASS $1"; }
bad(){ echo "FAIL $1"; fail=1; }
need_text(){ grep -Fq -- "$2" "$1" && pass "$3" || bad "$3"; }

need_text static/css/product-theme-m17h-r4.css \
  'padding: 0 32px 32px !important;' \
  'Games panel receives desktop inner gutter'

need_text static/css/product-theme-m17h-r4.css \
  '.branded-control-scoreboard .team-name' \
  'Control scoreboard team names have explicit contrast'

need_text static/css/product-theme-m17h-r4.css \
  '.roster-list .roster-player' \
  'Control roster rows have explicit contrast'

need_text static/css/product-theme-m17h-r4.css \
  'background: #f7f9fb !important;' \
  'Control roster rows use light surface'

need_text templates/games/index.html \
  '/static/css/product-theme-m17h-r4.css?v=m17h-r4' \
  'Games page loads Repair4 presentation layer'

need_text templates/control/game.html \
  '/static/css/product-theme-m17h-r4.css?v=m17h-r4' \
  'Control page loads Repair4 presentation layer'

exit "$fail"
