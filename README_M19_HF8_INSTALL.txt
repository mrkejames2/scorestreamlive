M19-HF8 Advertisement Artwork Library Integration

Apply from repository root:
  unzip -o m19-hf8-advertisement-artwork-library.zip
  python3 scripts/apply_m19_hf8_integrations.py

Then review git diff, rebuild the app so Alembic 0036 applies, and run:
  bash scripts/validate_m19_hf8.sh

Notes:
- Existing advertisement URLs are backfilled into Broadcast Artwork; files are not moved.
- Legacy /api/game-advertisement-assets remains for existing files.
- Clearing an Advertisement selection does not delete reusable artwork.
- Director can upload; Director/Manager can select existing artwork.
