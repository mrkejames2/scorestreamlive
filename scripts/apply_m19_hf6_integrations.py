#!/usr/bin/env python3
from pathlib import Path
def patch(path,old,new):
 p=Path(path);s=p.read_text()
 if new in s:print(path,"already integrated");return
 if old not in s:raise SystemExit(path+": expected anchor not found")
 p.write_text(s.replace(old,new,1));print(path,"integrated")
patch("app/models/game.py",'    intro_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)\n','    intro_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)\n    intro_artwork_id: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("broadcast_artworks.id", ondelete="RESTRICT"), nullable=True)\n    intro_artwork: Mapped[Optional["BroadcastArtwork"]] = relationship("BroadcastArtwork", foreign_keys=[intro_artwork_id])\n')
patch("app/models/game.py",'    thank_you_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)\n','    thank_you_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)\n    thank_you_artwork_id: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("broadcast_artworks.id", ondelete="RESTRICT"), nullable=True)\n    thank_you_artwork: Mapped[Optional["BroadcastArtwork"]] = relationship("BroadcastArtwork", foreign_keys=[thank_you_artwork_id])\n')
patch("app/models/__init__.py","from app.models.game import Game\n","from app.models.game import Game\nfrom app.models.broadcast_artwork import BroadcastArtwork\n")
patch("app/models/__init__.py",'    "Game",\n','    "Game",\n    "BroadcastArtwork",\n')
patch("app/main.py","from app.api.game_intro import router as game_intro_router\n","from app.api.game_intro import router as game_intro_router\nfrom app.api.broadcast_artwork import router as broadcast_artwork_router\n")
patch("app/main.py","app.include_router(game_intro_router)\n","app.include_router(game_intro_router)\napp.include_router(broadcast_artwork_router)\n")
patch("templates/games/detail.html",'<link rel="stylesheet" href="/static/css/game-intro-m19h.css?v=m19hf1b-1">','<link rel="stylesheet" href="/static/css/game-intro-m19h.css?v=m19hf1b-1">\n  <link rel="stylesheet" href="/static/css/broadcast-artwork-m19hf6.css?v=m19hf6-1">')
patch("templates/games/detail.html",'game-intro-m19h.js?v=m19h-1','game-intro-m19h.js?v=m19hf6-1')
patch("templates/games/detail.html",'game-thank-you-m19hf1b.js?v=m19hf1b-1','game-thank-you-m19hf1b.js?v=m19hf6-1')
print("M19 HF6 integrations complete")
