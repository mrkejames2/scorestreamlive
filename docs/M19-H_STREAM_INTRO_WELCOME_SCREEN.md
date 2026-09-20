# M19-H — Per-Game Stream Intro / Welcome Screen

Base: M19-G accepted commit `bbc829364df0c83d277f44e572014697aac8e6ca`.

M19-H adds optional game-specific Welcome Screen artwork, a stable `/stream/games/{game_id}` browser-source route, and server-authoritative `intro`/`live` presentation state. Director/Manager users may manage artwork for games they can operate; any authorized game operator may switch scenes. Scene changes are independent from the soccer lifecycle, so M19-G tracked appearances remain limited to first/second half. Intro exposure is intentionally untracked bonus exposure.

Artwork accepts PNG/JPEG/WebP with magic-byte validation, randomized immutable URLs and atomic writes. Local Docker uses `game_intro_data`; production must provide persistent storage at `GAME_INTRO_STORAGE_DIR`.
