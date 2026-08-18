# M11-F Release Notes

M11-F adds automatic broadcast presentation for committed lifecycle transitions.

Adds:
- FIRST HALF transition banner
- HALFTIME transition banner with current score
- SECOND HALF transition banner
- FULL TIME transition banner with final score
- automatic five-second dismissal
- duplicate phase-presentation suppression
- reconnect/bootstrap protection against replaying stale banners

Preserves:
- M11-E GOAL presentation
- M11-D broadcast scoreboard presentation
- M11-C 5-second authoritative clock resync
- performance.now() local clock interpolation
- Socket.IO committed-state synchronization
- last-known-good recovery behavior
- transparent OBS/Streamlabs canvas
- read-only overlay
- no clock:tick
