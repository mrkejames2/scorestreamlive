#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
pass(){ echo "PASS $1"; }
bad(){ echo "FAIL $1"; fail=1; }
need_text(){ grep -Fq -- "$2" "$1" && pass "$3" || bad "$3"; }

need_text static/css/product-theme-m17h-r5.css \
  '.branding-row code' \
  'Team color values have explicit readable contrast'

need_text static/css/product-theme-m17h-r5.css \
  '.team-id' \
  'Team IDs have explicit readable contrast'

need_text static/css/product-theme-m17h-r5.css \
  '.future-note' \
  'Team supporting copy has explicit readable contrast'

need_text static/css/product-theme-m17h-r5.css \
  '#primary-color' \
  'Team detail primary color text is readable'

need_text static/css/product-theme-m17h-r5.css \
  '#secondary-color' \
  'Team detail secondary color text is readable'

need_text templates/teams/index.html \
  '/static/css/product-theme-m17h-r5.css?v=m17h-r5' \
  'Teams index loads Repair5 presentation layer'

need_text templates/teams/detail.html \
  '/static/css/product-theme-m17h-r5.css?v=m17h-r5' \
  'Team detail loads Repair5 presentation layer'

exit "$fail"
