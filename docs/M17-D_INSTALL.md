# M17-D Install

From repo root, on `milestone/m17-d-user-invitation-activation` at M17-C baseline, unzip and apply:

```bash
unzip -o SCORESTREAMLIVE_M17-D_IMPLEMENTATION.zip
chmod +x scripts/apply_m17d.sh scripts/regression/user_invitation_activation.sh scripts/validate_m17d.sh
./scripts/apply_m17d.sh
git diff --check
git status --short
git diff --stat
```

Then rebuild/migrate:

```bash
sudo docker compose up -d --build
sudo docker compose exec app alembic upgrade head
sudo docker compose exec app alembic current
```
Expected: `20260905_0015 (head)`.

FAST:
```bash
sudo BASE_URL="http://localhost:8000" VALIDATION_MODE=local VALIDATION_SCOPE=fast VALIDATION_OUTPUT=full ./scripts/validate_m17d.sh
```
