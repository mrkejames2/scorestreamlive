# M11-D Release Notes

M11-D is a presentation-only milestone.

Adds:
- broadcast-style horizontal scoreboard
- compact ScoreStreamLive brand rail
- stronger score typography
- clearer clock and phase hierarchy
- LIVE / RECONNECTING presentation state
- 720p and 1080p-friendly responsive sizing
- last-known-good display preservation during temporary recovery failures
- transparent OBS/Streamlabs canvas

Preserves:
- PostgreSQL/server authority
- REST recovery
- Socket.IO committed-state synchronization
- 5-second clock-only authoritative resync
- `performance.now()` interpolation
- read-only overlay
- no `clock:tick`
