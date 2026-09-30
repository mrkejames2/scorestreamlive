M19 HF6 — Reusable Broadcast Artwork Library
From repo root:
  unzip -o m19-hf6-broadcast-artwork-library.zip
  python3 scripts/apply_m19_hf6_integrations.py
  sudo docker compose up -d --build
  sudo docker compose exec app alembic heads
  sudo docker compose exec app alembic current
  bash scripts/validate_m19_hf6.sh
No commit or push is performed.
