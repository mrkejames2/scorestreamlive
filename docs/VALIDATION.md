# ScoreStreamLive Validation Architecture

The active regression system is domain-based and executes each active check once. Historical milestone validators remain acceptance records; the active orchestrator does not recursively replay them.

Controls:

- `VALIDATION_MODE=local|production`
- `VALIDATION_SCOPE=fast|full|release`
- `VALIDATION_OUTPUT=summary|full`
- `VALIDATION_FAIL_FAST=0|1`

`fast` is cheap developer feedback and never restarts infrastructure. `full` is the extension point for complete current domain regression. `release` adds expensive recovery/resilience checks.

Every run captures logs under `.validation/runs/<timestamp>/` and updates `.validation/latest`. `VALIDATION_OUTPUT=full` prints failures from the same captured run; it never reruns the suite merely to expose diagnostics.

Historical milestone validators prove historical milestone acceptance. Durable current protection belongs in `scripts/regression/` by domain. New milestones must not extend recursive historical validator chains.
