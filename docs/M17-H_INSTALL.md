# M17-H Installation

Expected cumulative parent:

`5cb947c Complete M17-G compact broadcast overlay and brand integration`

Expected branch:

`milestone/m17-h-cohesive-product-theme`

From the repository root:

```bash
unzip -o SCORESTREAMLIVE_M17-H_IMPLEMENTATION.zip

chmod +x \
  scripts/apply_m17h.py \
  scripts/apply_m17h.sh \
  scripts/check_m17h.py \
  scripts/validate_m17h.sh \
  scripts/regression/cohesive_product_theme.sh

./scripts/apply_m17h.sh
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
./scripts/validate_m17h.sh
```

Expected cumulative target: **33/33 PASS**.

Then perform Human Acceptance before FULL validation.
