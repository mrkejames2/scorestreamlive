#!/usr/bin/env python3
from pathlib import Path
s=Path("app/services/game_sponsor_presentation_service.py").read_text();c=Path("app/api/control.py").read_text();o=Path("static/js/overlay/overlay.js").read_text();h=Path("static/js/overlay/sponsor-presentation-m19f.js").read_text();d=Path("Dockerfile").read_text();dc=Path("docker-compose.yml").read_text()
assert "serialize_public_presentation" in s and '"sponsor_presentation": await serialize_public_presentation' in c
assert "sponsorTiming" in o and "sponsorRenderGeneration" in o and "sponsorFailedArtwork" in o and "preloadImage" in o
assert "remainingMs" in h and "./static/uploads/sponsor-artwork" in d and "sponsor_artwork_data:/home/appuser/app/static/uploads/sponsor-artwork" in dc
print("PASS: M19-F hardening regression")
