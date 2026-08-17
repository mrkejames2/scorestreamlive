# ScoreStreamLive M10-F Regression Cleanup

This package fixes the remaining M10-F regression-chain failures without
weakening valid historical contracts.

## Included files

```text
scripts/validate_m10e.sh
scripts/validate_m9.sh
scripts/validate_m8b.sh
scripts/validate_m7c.sh
app/schemas/scoring_event.py
```

## Why `scoring_event.py` is included

The M7 architecture explicitly supports only:

```text
event_type = "goal"
```

The current M7-C validator correctly rejects `event_type="penalty"`.
The recent scoring schema cleanup accidentally widened `event_type` to an
arbitrary string, which allowed a penalty event to increment the Game score.

This package restores the approved M7 contract using:

```python
event_type: Literal["goal"]
```

The M7-C validator is intentionally preserved unchanged.

## Validator fixes

### M10-E

The historical M10-E scoring guard now recognizes the stronger M10-F
`scoringCommandInFlight` + `mutationStateIsReady()` safety model.

### M9

The historical M9 validation now checks that revision `20260815_0006`
exists in Alembic history rather than requiring the database's current head
to remain frozen at that revision.

### M8-B

Uses the same forward-compatible migration-history rule.

## Install

Copy all files into their matching repository paths.

Then rebuild because `app/schemas/scoring_event.py` is application code:

```bash
chmod +x scripts/validate_m7c.sh
chmod +x scripts/validate_m8b.sh
chmod +x scripts/validate_m9.sh
chmod +x scripts/validate_m10e.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Quick contract check

A non-goal scoring event should now return 422:

```bash
# The full M7-C harness verifies this automatically.
```

## Full validation

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m10f.sh
```

Do not begin M10-F human acceptance until this entire chain is green.
