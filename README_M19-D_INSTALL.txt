ScoreStreamLive M19-D implementation package
Base: milestone/m19-c-game-sponsor-assignment

cd ~/projects/scorestreamlive
git checkout milestone/m19-c-game-sponsor-assignment
git checkout -b milestone/m19-d-live-overlay-sponsor-placement
unzip -o SCORESTREAMLIVE_M19-D_IMPLEMENTATION.zip
python3 scripts/apply_m19d_integrations.py
sudo docker compose up -d --build app
./scripts/validate_m19d.sh

Repo-root-relative paths; no mv/cp required. No M19-D database migration.
