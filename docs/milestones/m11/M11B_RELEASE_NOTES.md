# M11-B Release Notes

M11-B adds real-time broadcast synchronization to the M11-A overlay.

Design:
- REST remains the authoritative bootstrap/recovery path.
- Socket.IO domain events act as committed-state invalidation signals.
- Relevant events are filtered to the overlay's `game_id`.
- The overlay re-reads authoritative REST state after relevant committed events.
- The clock renders locally between authoritative anchors.
- There is no per-second `clock:tick` consumer.
- Reconnect triggers authoritative recovery.
- The overlay remains read-only.

This package intentionally does not add visual redesign, logos, colors, sponsorship, or overlay customization. Those belong to later M11 sub-milestones.
