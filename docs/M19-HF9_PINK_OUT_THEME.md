# M19-HF9 Pink Out Theme
Adds persistent per-game `standard` / `pink_out` scoreboard themes. `games.overlay_theme` is authoritative. The existing `game:updated` recovery path updates the live overlay; scoring, clock, lifecycle, sponsor rotation, goal banners, and the stable Stream URL are unchanged. Unknown client values fall back to Standard and the database constrains valid values.
