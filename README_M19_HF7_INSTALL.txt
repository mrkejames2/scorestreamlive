M19 HF7 — Halftime Slideshow
Base: 730ef57 (HF6)

From repository root:
  unzip -o m19-hf7-halftime-slideshow.zip
  python3 scripts/apply_m19_hf7_integrations.py
  git diff --check
  git diff
  sudo docker compose up -d --build
  bash scripts/validate_m19_hf7.sh

HF7: reusable-artwork-backed ordered halftime slideshow; 5/10/15/20/30-second interval; stable /stream scene.
No sponsor reporting, scoring, clock, lifecycle, Venue Scoreboard, or Advertisement behavior changes.
