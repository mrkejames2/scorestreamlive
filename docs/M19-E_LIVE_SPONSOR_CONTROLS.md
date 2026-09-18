# M19-E — Live Sponsor Controls

Durable per-game sponsor presentation state plus Control Center controls for current sponsor, Previous/Next, Sponsor Zone show/hide, auto rotation on/off, and 5/10/15/20/30/45/60 second intervals. Mutations use `can_operate_game()` and same-origin protection. Socket.IO pushes control changes; REST state provides refresh/reconnect recovery. No sponsor billing or impression reporting is introduced in M19-E.
