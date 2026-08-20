# M11-E Release Notes

M11-E adds event-driven goal presentation to the broadcast overlay.

Adds:
- automatic GOAL banner on `scoring_event:created`
- scoring team display
- scorer name from the authoritative roster when available
- team-goal fallback when no player is selected
- game-minute display using `game_elapsed_seconds`
- five-second automatic dismissal
- duplicate scoring-event suppression
- simple entry/exit animation

Preserves:
- M11-D broadcast layout
- M11-C 5-second clock precision resync
- `performance.now()` local interpolation
- Socket.IO committed-state synchronization
- last-known-good recovery presentation
- transparent OBS/Streamlabs canvas
- read-only overlay
- no `clock:tick`
