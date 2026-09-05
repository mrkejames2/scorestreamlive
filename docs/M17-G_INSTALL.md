# M17-G Installation

Expected parent commit:

`60d9f40 Complete M17-F match-day workflow and operator polish`

Create the cumulative milestone branch:

```bash
git switch milestone/m17-f-match-day-workflow-operator-polish
git switch -c milestone/m17-g-compact-broadcast-overlay-brand
```

From the repository root, unzip the package directly:

```bash
unzip -o SCORESTREAMLIVE_M17-G_IMPLEMENTATION.zip
chmod +x \
  scripts/apply_m17g.py \
  scripts/apply_m17g.sh \
  scripts/validate_m17g.sh \
  scripts/regression/compact_broadcast_overlay_brand.sh
./scripts/apply_m17g.sh
```

Inspect:

```bash
git diff --check
git status --short
git diff --stat
git diff
```

Rebuild:

```bash
sudo docker compose down
sudo docker compose build app
sudo docker compose up -d
sudo docker compose ps
```

FAST:

```bash
sudo BASE_URL="http://localhost:8000" \
VALIDATION_MODE=local \
VALIDATION_SCOPE=fast \
VALIDATION_OUTPUT=full \
./scripts/validate_m17g.sh
```

Expected cumulative target: **32/32 PASS**.

Then perform Human Acceptance using real 1280x720 soccer footage before FULL validation.
