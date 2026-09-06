# M17-C Implementation Installation

Apply from the repository root on branch:

`milestone/m17-c-post-game-summary-broadcast`

Commands:

```bash
unzip -o SCORESTREAMLIVE_M17-C_IMPLEMENTATION.zip
chmod +x scripts/apply_m17c.sh scripts/regression/post_game_summary_broadcast.sh scripts/validate_m17c.sh
./scripts/apply_m17c.sh

git diff --check
git status --short
git diff --stat
git diff -- app/main.py scripts/validate.sh
```

Then rebuild:

```bash
sudo docker compose up -d --build
sudo docker compose ps
sudo docker compose exec app alembic current
```

No new migration is expected; Alembic should remain at `20260904_0014 (head)`.

Run FAST first:

```bash
sudo BASE_URL="http://localhost:8000" \
VALIDATION_MODE=local \
VALIDATION_SCOPE=fast \
VALIDATION_OUTPUT=full \
./scripts/validate_m17c.sh
```

Do not commit until FAST, FULL, and Human Acceptance pass.
