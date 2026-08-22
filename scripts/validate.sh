#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
source scripts/lib/validation.sh; validation_init || exit $?; validation_run_dir
declare -a NAMES=() SCRIPTS=() RESULTS=()
add(){ NAMES+=("$1"); SCRIPTS+=("$2"); }
add Health scripts/regression/health.sh
add 'Web Surfaces' scripts/regression/surfaces.sh
add 'API Reads' scripts/regression/api_reads.sh
add Architecture scripts/regression/architecture.sh
add 'Game Library' scripts/regression/game_library.sh
add 'Game Dashboard' scripts/regression/game_dashboard.sh
add 'Game Search/Filter' scripts/regression/game_search_filter.sh
add 'Game Retrieval' scripts/regression/game_retrieval.sh
if [[ "$VALIDATION_SCOPE" == release ]]; then add Recovery scripts/regression/recovery.sh; fi
fails=0
echo '========================================'
echo 'ScoreStreamLive Validation'
echo "BASE_URL: $BASE_URL"
echo "MODE: $VALIDATION_MODE"
echo "SCOPE: $VALIDATION_SCOPE"
echo "OUTPUT: $VALIDATION_OUTPUT"
echo "RUN: $VALIDATION_RUN_DIR"
echo '========================================'
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"; script="${SCRIPTS[$i]}"; slug="$(basename "$script" .sh)"; log="$VALIDATION_RUN_DIR/logs/${slug}.log"
  printf '[%d/%d] %s... ' "$((i+1))" "${#NAMES[@]}" "$name"
  set +e
  BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" VALIDATION_SCOPE="$VALIDATION_SCOPE" VALIDATION_OUTPUT="$VALIDATION_OUTPUT" "$script" >"$log" 2>&1
  rc=$?
  set -e
  if [[ "$rc" == 0 ]]; then RESULTS+=(PASS); echo PASS; else RESULTS+=(FAIL); fails=$((fails+1)); echo FAIL; [[ "$VALIDATION_OUTPUT" == full ]] && { echo "----- $name detail -----"; cat "$log"; echo '-------------------------'; }; [[ "$VALIDATION_FAIL_FAST" == 1 ]] && break; fi
done
summary="$VALIDATION_RUN_DIR/summary.txt"
{
 echo '========================================'; echo 'ScoreStreamLive Validation Summary'; echo "SCOPE: $VALIDATION_SCOPE"; echo '========================================'
 for i in "${!RESULTS[@]}"; do printf '%-24s %s\n' "${NAMES[$i]}" "${RESULTS[$i]}"; done
 echo '========================================'
 if [[ "$fails" == 0 ]]; then echo 'OVERALL                  PASS'; else echo 'OVERALL                  FAIL'; echo; echo 'Failed Components:'; for i in "${!RESULTS[@]}"; do [[ "${RESULTS[$i]}" == FAIL ]] && echo "- ${NAMES[$i]} (log: $VALIDATION_RUN_DIR/logs/$(basename "${SCRIPTS[$i]}" .sh).log)"; done; fi
 echo '========================================'
} | tee "$summary"
if [[ "$fails" != 0 ]]; then [[ "$VALIDATION_OUTPUT" == summary ]] && { echo; echo "Failure details already captured in $VALIDATION_RUN_DIR/logs/"; echo 'No tests need to be rerun to inspect them.'; }; exit 1; fi
