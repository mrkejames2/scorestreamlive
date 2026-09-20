ScoreStreamLive M19-F — Sponsor Presentation & Production Hardening
BASE: milestone/m19-e-live-sponsor-controls @ d8cf709a3d1b37cd15efd9e653cd8403aa8075b8

Unzip from repository root, then run:
  python3 scripts/apply_m19f_integrations.py
  sudo docker compose up -d --build app
  ./scripts/validate_m19f.sh

No Alembic migration. Expected head/current remains 20260918_0029.
Do not update main; cumulative M19 remains on milestone branches.
