# M10-E Human-Acceptance Cleanup

This package implements the three items found during the iPhone acceptance test:

1. Remove technical IDs/version fields from the normal operator UI.
2. Use clean human-facing demo names (`Saginaw United`, `Detroit City`).
3. Show the soccer match minute in Scoring Summary instead of wall-clock time.

## Important architecture decision

Goal time is durable server-authoritative data.

A new nullable `scoring_events.game_elapsed_seconds` column stores the M8 clock
snapshot when a goal is accepted. Existing historical rows remain NULL rather
than receiving a fabricated value.

## Files

Replace:

```text
templates/control/game.html
static/js/control/control.js
scripts/create_m10e_demo.sh
app/models/scoring_event.py
app/schemas/scoring_event.py
```

Add:

```text
alembic/versions/20260817_0007_add_scoring_event_game_elapsed_seconds.py
scripts/validate_m10e_human_cleanup.sh
```

Then apply the small scoring-service integration described in:

```text
M10E_SCORING_SERVICE_PATCH.md
```

## Rebuild

```bash
chmod +x scripts/create_m10e_demo.sh
chmod +x scripts/validate_m10e_human_cleanup.sh

sudo docker compose down
sudo docker compose up --build -d
```

The normal entrypoint should run migration `20260817_0007`.

Verify:

```bash
sudo docker compose exec -T app alembic current
```

Expected:

```text
20260817_0007 (head)
```

## Validate cleanup

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m10e_human_cleanup.sh
```

Then rerun the full M10-E chain:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m10e.sh
```

## Fresh demo

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m10e_demo.sh
```

The Control Center should show clean names without timestamp suffixes.

Record a goal after the clock has run into a known minute. The Scoring Summary
should show soccer notation such as:

```text
12'
32'
45'
54'
```

The database `created_at` remains intact for audit/debug purposes but is no
longer shown as the match-time value.
