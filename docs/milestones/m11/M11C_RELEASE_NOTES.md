# M11-C Release Notes

M11-C hardens clock rendering without changing the authoritative architecture.

Changes:
- Uses `performance.now()` for monotonic local interpolation.
- Avoids `Date.now()` for elapsed interpolation so device system-clock changes cannot move the match clock.
- Re-anchors to authoritative REST state every 30 seconds.
- Immediately re-anchors when a suspended/backgrounded browser becomes visible.
- Preserves Socket.IO committed-state invalidation from M11-B.
- Preserves local 250ms visual rendering.
- Preserves read-only overlay behavior.
- Preserves the no-`clock:tick` architecture.

M11-C deliberately does not redesign overlay visuals. Broadcast styling remains for M11-D.
