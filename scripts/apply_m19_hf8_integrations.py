from pathlib import Path

def patch(path,old,new):
 p=Path(path);s=p.read_text()
 if new in s:return
 if old not in s:raise SystemExit(f"Expected integration point not found: {path}")
 p.write_text(s.replace(old,new,1))

patch("app/models/game.py",
'    advertisement_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)\n',
'    advertisement_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)\n    advertisement_artwork_id: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("broadcast_artworks.id", ondelete="RESTRICT"), nullable=True)\n    advertisement_artwork: Mapped[Optional["BroadcastArtwork"]] = relationship("BroadcastArtwork", foreign_keys=[advertisement_artwork_id])\n')
patch("app/api/broadcast_artwork.py",
'Game.intro_artwork_id==a.id,Game.thank_you_artwork_id==a.id',
'Game.intro_artwork_id==a.id,Game.thank_you_artwork_id==a.id,Game.advertisement_artwork_id==a.id')
patch("templates/games/detail.html",
'<div><span class="eyebrow">STREAM ADVERTISEMENT</span><h2>Per-Game Broadcast Advertisement</h2><p>Recommended 16:9 artwork, 1280×720 or higher.</p></div>',
'<div><span class="eyebrow">STREAM ADVERTISEMENT</span><h2>Per-Game Broadcast Advertisement</h2><p>Select reusable artwork from your club library. Recommended 16:9 artwork, 1280×720 or higher.</p></div>')
patch("templates/games/detail.html",
'/static/js/games/game-advertisement-m19hf2.js?v=m19hf2-1',
'/static/js/games/game-advertisement-m19hf2.js?v=m19hf8-1')
print("M19 HF8 integrations applied")
