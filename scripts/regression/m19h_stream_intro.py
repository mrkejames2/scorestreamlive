from pathlib import Path
def must(path,*needles):
 s=Path(path).read_text()
 for n in needles:assert n in s,f"{path}: missing {n}"
must("app/models/game_broadcast_presentation.py","scene","version")
must("app/services/game_broadcast_presentation_service.py","intro","live","expected_version")
must("app/services/game_intro_artwork_storage.py","RIFF","os.replace")
must("alembic/versions/20260920_0031_add_game_stream_intro.py","20260920_0030","intro_image_url","game_broadcast_presentations")
must("static/js/broadcast/game-m19h.js","broadcast:presentation_updated","broadcast-state")
must("app/services/sponsor_impression_service.py","first_half","second_half")
print("PASS: M19-H stream intro regression")
print("PASS: M19-H sponsor tracking isolation regression")
