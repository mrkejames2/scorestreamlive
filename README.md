# ScoreStreamLive M10-E Validation Fix

Replacement validation scripts only. No application/backend/UI changes.

## Fixes

- `validate_m10c.sh`
  - Removes the obsolete requirement that the current Control Center identify as M10-C.
  - Removes the obsolete requirement that scoring mutation UI be absent.
  - Preserves lifecycle controls, optimistic version handling, 409 handling,
    authoritative refresh, local clock rendering, transition behavior, and race tests.

- `validate_m10d.sh`
  - Removes the obsolete requirement that the current Control Center identify as M10-D.
  - Validates that the M10-D scoring-control capability remains present.

- `validate_m10e.sh`
  - Keeps the current M10-E UX checks.
  - Continues chaining M10-D -> M10-C -> M10-B -> M10-A -> M9 regressions.

## Install

From the ScoreStreamLive repository root:

```bash
cp /path/to/package/scripts/validate_m10c.sh scripts/validate_m10c.sh
cp /path/to/package/scripts/validate_m10d.sh scripts/validate_m10d.sh
cp /path/to/package/scripts/validate_m10e.sh scripts/validate_m10e.sh
chmod +x scripts/validate_m10c.sh scripts/validate_m10d.sh scripts/validate_m10e.sh
```

Then run:

```bash
sudo BASE_URL="http://192.168.12.133:8000" ./scripts/validate_m10e.sh
```
