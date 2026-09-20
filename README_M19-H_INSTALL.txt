ScoreStreamLive M19-H — Per-Game Stream Intro / Welcome Screen

BASE COMMIT: bbc829364df0c83d277f44e572014697aac8e6ca

1) git checkout -b milestone/m19-h-stream-intro-welcome-screen
2) Unzip this archive in the repository root.
3) python3 scripts/apply_m19h_integrations.py
4) git diff --check && git status --short
5) sudo docker compose up -d --build
6) bash scripts/validate_m19h.sh

No automatic commit. Do not update main.
