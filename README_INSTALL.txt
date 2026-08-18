M11 FINAL CLEANUP

Replace:
  scripts/validate_m11g.sh
  AI_HANDOFF.md

No Docker rebuild is required for the validator or markdown update.

Optional focused rerun:
  sudo BASE_URL="http://192.168.12.133:8000" ./scripts/validate_m11g.sh

Then review git diff/status before commit/push.
