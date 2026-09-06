#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
pass(){ echo "PASS $1"; }
bad(){ echo "FAIL $1"; fail=1; }
need_text(){ grep -Fq -- "$2" "$1" && pass "$3" || bad "$3"; }

need_text static/css/product-theme-m17h-r3.css \
  'width: min(1180px, calc(100% - 72px)) !important;' \
  'desktop Games content has horizontal gutter'

need_text static/css/product-theme-m17h-r3.css \
  'padding-top: 28px !important;' \
  'desktop Games content has top spacing'

need_text templates/games/index.html \
  '/static/css/product-theme-m17h-r3.css?v=m17h-r3' \
  'Games index loads Repair3 spacing layer'

exit "$fail"
