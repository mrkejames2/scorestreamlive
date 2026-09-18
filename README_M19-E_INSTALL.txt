ScoreStreamLive M19-E implementation package
Base: milestone/m19-d-live-overlay-sponsor-placement @ 951f4bf

From ~/projects/scorestreamlive on milestone/m19-e-live-sponsor-controls:

unzip -o SCORESTREAMLIVE_M19-E_IMPLEMENTATION.zip
python3 scripts/apply_m19e_integrations.py
sudo docker compose up -d --build app
./scripts/validate_m19e.sh

Expected Alembic head/current: 20260918_0029. Repo-root-relative paths; no mv/cp required. No commit is performed.
