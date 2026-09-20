M19-G — Sponsor Impression Tracking & Reporting
BASE: accepted M19-F commit ed47cf298460755186dfc5717bb85145a39e0f60
BRANCH: milestone/m19-g-sponsor-impression-tracking-reporting

Upload this ZIP to the repository root and unzip there. Paths are repo-root-relative.
Run: python3 scripts/apply_m19g_integrations.py
Review git diff, then rebuild normally. The app entrypoint runs Alembic upgrade head.
Verify with normal interactive commands:
  sudo docker compose exec app alembic heads
  sudo docker compose exec app alembic current
Expected head/current: 20260920_0030
Run: ./scripts/validate_m19g.sh
Then complete the seven human acceptance tests in the M19-G doc.
Do not update main. Do not auto-commit.
