#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
pass(){ echo "PASS $1"; }
bad(){ echo "FAIL $1"; fail=1; }
need_text(){ grep -Fq -- "$2" "$1" && pass "$3" || bad "$3"; }

need_text static/js/account-nav.js 'link.classList.toggle("active", active)' 'sidebar active state is route-aware'
need_text static/js/account-nav.js 'link.setAttribute("aria-current", "page")' 'sidebar uses aria-current for active page'
need_text static/js/account-nav.js 'path.startsWith("/games/")' 'Games child routes highlight Games'
need_text static/js/account-nav.js 'path.startsWith("/teams/")' 'Teams child routes highlight Teams'
need_text static/js/account-nav.js 'path.startsWith("/account/")' 'Account child routes highlight Account'
need_text static/css/product-theme-m17h-r2.css '.ssl-nav-link.active' 'active navigation styling exists'
need_text static/css/product-theme-m17h-r2.css '.ssl-nav-account' 'permanent Account highlight is neutralized'

exit "$fail"
