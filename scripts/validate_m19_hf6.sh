#!/usr/bin/env bash
set -euo pipefail
BASE="${BASE_URL:-http://127.0.0.1:8000}"
for i in $(seq 1 30);do curl -fsS "$BASE/health/ready" >/dev/null && break;[ "$i" = 30 ] && { sudo docker compose ps;sudo docker compose logs --tail=120 app;exit 1;};sleep 2;done
curl -fsS "$BASE/health/live" >/dev/null
sudo docker compose exec app alembic heads
sudo docker compose exec app alembic current
sudo docker compose exec -T app python - <<'PY'
from app.models.broadcast_artwork import BroadcastArtwork
from app.models.game import Game
assert BroadcastArtwork.__tablename__=="broadcast_artworks"
assert hasattr(Game,"intro_artwork_id") and hasattr(Game,"thank_you_artwork_id")
print("M19 HF6 model smoke: PASS")
PY
echo "M19 HF6 fast validation: PASS"
