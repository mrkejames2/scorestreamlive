#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }
require_file(){ [[ -f "$1" ]] || fail "missing $1"; }
require_text(){ local f="$1" t="$2"; grep -Fq -- "$t" "$f" || fail "$f missing invariant: $t"; }
TEMPLATE="templates/control/game.html"
WORKFLOW="static/js/control/m17f-workflow.js"
STYLE="static/css/control-m17f.css"
STATE="static/js/control/state.js"
CONTROL="static/js/control/control.js"
for f in "$TEMPLATE" "$WORKFLOW" "$STYLE" "$STATE" "$CONTROL"; do require_file "$f"; done
require_text "$TEMPLATE" 'id="m17f-match-readiness"'
require_text "$TEMPLATE" 'id="m17f-primary-action"'
require_text "$TEMPLATE" 'id="m17f-recent-activity"'
require_text "$TEMPLATE" 'id="m17f-postgame-actions"'
require_text "$TEMPLATE" '/static/css/control-m17f.css'
require_text "$TEMPLATE" '/static/js/control/m17f-workflow.js'
require_text "$STATE" 'export const state = {'
require_text "$WORKFLOW" 'import { state } from "./state.js";'
require_text "$WORKFLOW" 'state.socketConnected'
require_text "$WORKFLOW" 'state.stateAuthoritative'
require_text "$WORKFLOW" 'state.connectionState === "live"'
require_text "$WORKFLOW" 'function renderReadiness()'
require_text "$WORKFLOW" 'function renderPrimaryAction()'
require_text "$WORKFLOW" 'function renderActivity()'
require_text "$WORKFLOW" 'function renderPostgame()'
require_text "$WORKFLOW" 'Primary action follows the current authoritative match phase.'
require_text "$WORKFLOW" 'state.game?.archived_at'
require_text "$WORKFLOW" 'state.lifecycle?.phase === "full_time"'
require_text "$WORKFLOW" 'function enforceReadOnlyControls()'
require_text "$CONTROL" 'commandInFlight'
require_text "$CONTROL" 'scoringCommandInFlight'
require_text "$CONTROL" 'clockCommandInFlight'
require_text "$CONTROL" 'clockConfigInFlight'
require_text "$CONTROL" 'broadcastMessageInFlight'
require_text "$CONTROL" 'function lifecycleConfirmation(action)'
require_text "$CONTROL" 'action === "end_first_half"'
require_text "$CONTROL" 'action === "end_game"'
require_text "$CONTROL" 'confirmation && !window.confirm(confirmation)'
require_text "$CONTROL" 'Change Scorer'
require_text "$CONTROL" 'Remove Goal'
require_text "$CONTROL" 'Score correction — ${correctedName} scored.'
require_text "$CONTROL" 'function mutationStateIsReady()'
require_text "$WORKFLOW" '/summary/games/${gameId}'
require_text "$WORKFLOW" '/broadcast/games/${gameId}'
require_text "$STYLE" '@media (max-width:760px)'
require_text "$STYLE" '@media (max-width:480px)'
if find alembic/versions -maxdepth 1 -type f \( -iname '*m17f*' -o -iname '*match*day*workflow*operator*polish*' \) | grep -q .; then fail "M17-F unexpectedly introduced a migration"; fi
if grep -R -Eqi --exclude-dir=.git --exclude='match_day_workflow_operator_polish.sh' '(redis|kafka|nats|rabbitmq|celery)' "$WORKFLOW" "$STYLE" "$TEMPLATE"; then fail "M17-F introduced prohibited infrastructure"; fi
echo "Match-Day Workflow & Operator Polish regression checks passed."
