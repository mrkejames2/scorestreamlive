#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing $1"
}

require_text() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || fail "$file missing invariant: $text"
}

require_regex() {
  local file="$1"
  local regex="$2"
  grep -Eq -- "$regex" "$file" || fail "$file missing invariant matching: $regex"
}

CONTROL="static/js/control/control.js"
SCORING="app/services/scoring_service.py"

require_file "$CONTROL"
require_file "$SCORING"

# Destructive lifecycle transitions require deliberate confirmation while
# normal start-of-half transitions remain one-command operations.
require_text "$CONTROL" 'function lifecycleConfirmation(action)'
require_text "$CONTROL" 'action === "end_first_half"'
require_text "$CONTROL" 'action === "end_game"'
require_text "$CONTROL" 'confirmation && !window.confirm(confirmation)'

# All match-day mutation families remain gated by authoritative live state.
require_text "$CONTROL" 'function mutationStateIsReady()'
require_text "$CONTROL" 'mutationStateIsReady()'
require_text "$CONTROL" 'const correctionReady = mutationStateIsReady() && !scoringCommandInFlight;'
require_text "$CONTROL" 'mutationStateIsReady()'
require_text "$CONTROL" 'clockCommandInFlight'
require_text "$CONTROL" 'clockConfigInFlight'
require_text "$CONTROL" 'scoringCommandInFlight'
require_text "$CONTROL" 'commandInFlight'

# Same-scorer corrections are no-ops in both browser and server boundaries.
require_text "$CONTROL" 'selectedPlayerId === currentPlayerId'
require_text "$CONTROL" 'Scorer is already correct. No change was sent.'
require_text "$SCORING" 'if event.player_id == player_id:'
require_regex "$SCORING" 'if event\.player_id == player_id:[[:space:]]*$'

# Existing server integrity invariants must remain intact.
require_text "$SCORING" 'Team does not participate in this Game'
require_text "$SCORING" 'Player does not belong to the scoring Team'
require_text "$SCORING" 'request_id was already used for a different scoring command'
require_text "$SCORING" 'max(0, int(game.home_score) - 1)'
require_text "$SCORING" 'max(0, int(game.away_score) - 1)'

# Operator feedback must describe committed correction state clearly.
require_text "$CONTROL" 'Score correction — ${correctedName} scored.'
require_text "$CONTROL" 'Goal removed — score corrected to ${scoreline()}.'
require_text "$CONTROL" '${team.name} goal recorded — ${scoringLabel}.'
require_text "$CONTROL" 'Another controller changed the game first.'
require_text "$CONTROL" 'Another controller changed the clock first.'

# M16-D does not change the public Overlay boundary or introduce new infra.
if grep -R -Eqi --exclude-dir=.git --exclude='operator_ux_data_integrity.sh' \
  '(redis|kafka|nats|rabbitmq|celery)' \
  static/js/control/control.js app/services/scoring_service.py; then
  fail "M16-D introduced a prohibited broker/queue dependency"
fi

# Production validation is source-safe: this domain performs no synthetic
# mutation against BASE_URL. Previous domains retain their own mode behavior.
echo "Operator UX/Data Integrity regression checks passed."
