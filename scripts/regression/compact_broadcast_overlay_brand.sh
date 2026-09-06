#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
pass(){ echo "PASS $1"; }
bad(){ echo "FAIL $1"; fail=1; }
need_file(){ [[ -f "$1" ]] && pass "$1 present" || bad "$1 missing"; }
need_text(){ grep -Fq "$2" "$1" && pass "$3" || bad "$3"; }

for file in \
  templates/overlay/game.html \
  static/css/overlay-m17g.css \
  static/js/overlay/m17g-layout.js \
  static/brand/scorestreamlive-mark.svg \
  static/brand/scorestreamlive-logo.png \
  docs/M17-G_COMPACT_BROADCAST_OVERLAY_BRAND_INTEGRATION.md
do
  need_file "$file"
done

need_text templates/overlay/game.html \
  'data-overlay-layout="compact"' \
  'compact presentation is server-rendered as the default'
need_text templates/overlay/game.html \
  '/static/css/overlay-m17g.css' \
  'M17-G overlay stylesheet is registered'
need_text templates/overlay/game.html \
  '/static/js/overlay/m17g-layout.js' \
  'M17-G layout selector is registered'
need_text static/js/overlay/m17g-layout.js \
  'requested === "standard" ? "standard" : "compact"' \
  'only compact/standard presentation modes are accepted'
need_text static/css/overlay-m17g.css \
  'body[data-overlay-layout="compact"] .overlay-scoreboard' \
  'compact scoreboard contract exists'
need_text static/css/overlay-m17g.css \
  'width: min(640px, calc(100vw - 32px));' \
  'final New Compact 1280x720 footprint target is encoded'
need_text static/css/overlay-m17g.css \
  'body[data-overlay-layout="standard"] .overlay-scoreboard' \
  'optional standard scoreboard contract exists'
need_text static/css/overlay-m17g.css \
  'scorestreamlive-mark.svg' \
  'ScoreStreamLive compact mark is integrated'
need_text static/css/overlay-m17g.css \
  '.goal-banner {' \
  'smaller scoring notification contract exists'
need_text static/css/overlay-m17g.css \
  '.broadcast-overlay-banner {' \
  'smaller broadcast alert contract exists'
need_text static/css/overlay-m17g.css \
  '.score-correction-banner {' \
  'score correction presentation remains covered'

need_text static/css/overlay-m17g.css \
  '/* Locked SCORE CORRECTION presentation: lower-left. */' \
  'score correction presentation is locked to lower-left'


need_text templates/overlay/game.html \
  'id="score-correction-meta"' \
  'score correction includes time/phase metadata region'
need_text static/js/overlay/overlay.js \
  'message.textContent = `${teamName} — ${status}`;' \
  'score correction identifies the affected Team'


need_text templates/overlay/game.html \
  '<span class="goal-banner-word">GOAL!</span>' \
  'final GOAL callout text is rendered'
need_text templates/overlay/game.html \
  'class="goal-banner-callout"' \
  'final GOAL card has dedicated callout region'
need_text templates/overlay/game.html \
  'id="goal-meta"' \
  'final GOAL card includes phase metadata'
need_text static/css/overlay-m17g.css \
  'grid-template-columns: 210px 86px minmax(0, 1fr);' \
  'final GOAL card uses approved three-region layout'
need_text static/css/overlay-m17g.css \
  'background: linear-gradient(135deg, #0aa63d 0%, #078d35 62%, #056a2a 100%);' \
  'final GOAL callout uses approved green treatment'
need_text static/js/overlay/overlay.js \
  'const half = phase ? phaseLabel(phase) : renderedPhase;' \
  'final GOAL card renders current phase'

need_text templates/overlay/game.html \
  'id="goal-meta"' \
  'Repair 6 GOAL card uses one metadata node'
need_text static/js/overlay/overlay.js \
  'goalMeta.textContent = [minute, half].filter(Boolean).join(" • ");' \
  'Repair 6 GOAL metadata includes minute and half'
need_text static/js/overlay/overlay.js \
  'const half = phase ? phaseLabel(phase) : renderedPhase;' \
  'Repair 6 GOAL derives half label explicitly'

# Presentation milestone must not introduce an Alembic migration.
if find alembic/versions -maxdepth 1 -type f -name '*0017*' -print -quit | grep -q .; then
  bad 'unexpected M17-G database migration detected'
else
  pass 'M17-G remains migration-free'
fi

# Runtime checks are read-only and production-safe.
if [[ -n "${BASE_URL:-}" ]]; then
  for path in \
    "/static/css/overlay-m17g.css" \
    "/static/js/overlay/m17g-layout.js" \
    "/static/brand/scorestreamlive-mark.svg" \
    "/static/brand/scorestreamlive-logo.png"
  do
    code="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL$path" || true)"
    [[ "$code" == "200" ]] && pass "$path served" || bad "$path expected HTTP 200, got $code"
  done

  RANDOM_GAME="00000000-0000-0000-0000-000000000017"
  rendered="$(curl -fsS "$BASE_URL/overlay/games/$RANDOM_GAME" || true)"
  if printf '%s' "$rendered" | grep -Fq 'data-overlay-layout="compact"' \
     && printf '%s' "$rendered" | grep -Fq '/static/css/overlay-m17g.css' \
     && printf '%s' "$rendered" | grep -Fq '/static/js/overlay/m17g-layout.js'; then
    pass 'rendered public overlay carries M17-G compact contract'
  else
    bad 'rendered public overlay missing M17-G compact contract'
  fi
fi

exit "$fail"
