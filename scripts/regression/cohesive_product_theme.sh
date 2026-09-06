#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
pass(){ echo "PASS $1"; }
bad(){ echo "FAIL $1"; fail=1; }
need_file(){ [[ -f "$1" ]] && pass "$2" || bad "$2"; }
need_text(){ grep -Fq -- "$2" "$1" && pass "$3" || bad "$3"; }

need_file static/brand/scorestreamlive-logo.png 'canonical product logo present'
need_file static/css/product-theme-m17h.css 'M17-H product theme present'

need_text static/css/product-theme-m17h.css '--ssl-navy-900: #0b2435;' 'canonical deep navy token is locked'
need_text static/css/product-theme-m17h.css '--ssl-orange: #fe6505;' 'canonical ScoreStreamLive orange token is locked'
need_text static/css/product-theme-m17h.css '--ssl-page: #f4f6f8;' 'clean light application background is locked'
need_text static/css/product-theme-m17h.css '--ssl-card: #ffffff;' 'white application card surface is locked'
need_text static/css/product-theme-m17h.css '--ssl-text: #172b3a;' 'dark readable application text is locked'
need_text static/css/product-theme-m17h.css '.games-panel' 'game dashboard surface contract exists'
need_text static/css/product-theme-m17h.css '.game-card' 'game card surface contract exists'
need_text static/css/product-theme-m17h.css '.game-scoreline' 'game scoreline contrast contract exists'
need_text static/css/product-theme-m17h.css '.ssl-account-nav' 'approved navy navigation treatment exists'
need_text static/css/product-theme-m17h.css 'games-footer > *' 'customer-facing milestone footer is suppressed'
need_text static/css/product-theme-m17h.css '.button-primary' 'shared primary-button theme exists'
need_text static/css/product-theme-m17h.css 'input:focus' 'shared form focus treatment exists'

for template in \
  templates/account/index.html \
  templates/auth/activate.html \
  templates/auth/activate_invalid.html \
  templates/auth/forgot_password.html \
  templates/auth/login.html \
  templates/auth/reset_password.html \
  templates/auth/reset_password_invalid.html \
  templates/broadcast/game.html \
  templates/control/game.html \
  templates/games/detail.html \
  templates/games/index.html \
  templates/games/setup.html \
  templates/summary/game.html \
  templates/teams/detail.html \
  templates/teams/index.html
do
  need_text "$template" \
    '/static/css/product-theme-m17h.css?v=m17h-r1' \
    "$template uses cache-busted M17-H Repair1 theme"
done

need_text templates/overlay/game.html '/static/css/overlay-m17g.css?v=m17h-1' 'M17-G overlay CSS cache-busting preserved'
need_text templates/overlay/game.html '/static/js/overlay/m17g-layout.js?v=m17h-1' 'M17-G layout JS cache-busting preserved'
need_text templates/overlay/game.html '/static/js/overlay/overlay.js?v=m17h-1' 'overlay runtime JS cache-busting preserved'

need_text scripts/validate.sh \
  "add 'Cohesive Product Theme & UI Consistency' scripts/regression/cohesive_product_theme.sh" \
  'M17-H validation domain remains registered'

if find alembic/versions -maxdepth 1 -type f \( -iname '*m17h*' -o -iname '*cohesive*product*theme*' \) -print -quit | grep -q .; then
  bad 'unexpected M17-H database migration detected'
else
  pass 'M17-H remains migration-free'
fi

if [[ -n "${BASE_URL:-}" ]]; then
  for path in \
    "/static/css/product-theme-m17h.css?v=m17h-r1" \
    "/static/brand/scorestreamlive-logo.png?v=m17h-1" \
    "/static/brand/scorestreamlive-mark.svg?v=m17h-1"
  do
    code="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL$path" || true)"
    [[ "$code" == "200" ]] && pass "$path served" || bad "$path expected HTTP 200, got $code"
  done

  login="$(curl -fsS "$BASE_URL/login" || true)"
  if printf '%s' "$login" | grep -Fq '/static/css/product-theme-m17h.css?v=m17h-r1'; then
    pass 'login renders repaired M17-H product theme'
  else
    bad 'login missing repaired M17-H product theme'
  fi

  games="$(curl -fsS "$BASE_URL/games" || true)"
  if printf '%s' "$games" | grep -Fq '/static/css/product-theme-m17h.css?v=m17h-r1'; then
    pass 'games renders repaired M17-H product theme'
  else
    bad 'games missing repaired M17-H product theme'
  fi

  random_game="00000000-0000-0000-0000-000000000017"
  overlay="$(curl -fsS "$BASE_URL/overlay/games/$random_game" || true)"
  if printf '%s' "$overlay" | grep -Fq '/static/js/overlay/overlay.js?v=m17h-1'; then
    pass 'public overlay keeps versioned M17-G JS asset'
  else
    bad 'public overlay missing versioned M17-G JS asset'
  fi
fi

exit "$fail"
