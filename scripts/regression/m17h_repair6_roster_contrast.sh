#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
pass(){ echo "PASS $1"; }
bad(){ echo "FAIL $1"; fail=1; }
need_text(){ grep -Fq -- "$2" "$1" && pass "$3" || bad "$3"; }

need_text static/css/product-theme-m17h-r6.css \
  '.game-summary' \
  'Game Setup summary has explicit contrast'

need_text static/css/product-theme-m17h-r6.css \
  '.roster-card' \
  'Roster cards have explicit contrast'

need_text static/css/product-theme-m17h-r6.css \
  '.player-row' \
  'Roster player rows have explicit contrast'

need_text static/css/product-theme-m17h-r6.css \
  '.player-name' \
  'Roster player names have explicit readable contrast'

need_text templates/games/setup.html \
  '/static/css/product-theme-m17h-r6.css?v=m17h-r6' \
  'Game Setup loads Repair6 presentation layer'

exit "$fail"
