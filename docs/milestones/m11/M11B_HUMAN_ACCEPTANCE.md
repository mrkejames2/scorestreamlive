# M11-B Human Acceptance — Live Broadcast Overlay

M11-A human checkpoint established the key production requirement: a Streamlabs/OBS overlay cannot depend on manual refresh.

## Required test

- [ ] Open Control Center on one device.
- [ ] Open overlay on another browser/device.
- [ ] Do not refresh the overlay after initial load.
- [ ] Start First Half; overlay phase changes automatically.
- [ ] Overlay clock starts automatically.
- [ ] Clock continues smoothly without per-second Socket.IO ticks.
- [ ] Score a Home goal; overlay score changes automatically.
- [ ] Score an Away goal; overlay score changes automatically.
- [ ] End First Half; overlay stops at authoritative time and shows Halftime.
- [ ] Start Second Half; overlay updates automatically and clock runs.
- [ ] Make a change from a second Control Center; overlay updates.
- [ ] Disconnect overlay network temporarily.
- [ ] Continue game from Control Center.
- [ ] Reconnect overlay network.
- [ ] Overlay automatically recovers current authoritative score, phase, and clock.
- [ ] Overlay never exposes controls or mutation actions.
- [ ] No manual browser/Streamlabs refresh was required.

Automated M11-B validation: PASS / FAIL

Human M11-B acceptance: PASS / FAIL
