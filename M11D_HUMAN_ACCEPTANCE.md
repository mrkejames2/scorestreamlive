# M11-D Human Acceptance — Broadcast Presentation

## Visual acceptance
- [ ] Overlay background outside scoreboard is fully transparent.
- [ ] Scoreboard looks intentional/professional rather than like a web form.
- [ ] Home and Away are immediately distinguishable.
- [ ] Team abbreviations/names are readable.
- [ ] Scores are the strongest visual element.
- [ ] Clock is prominent and easy to read.
- [ ] Match phase is visible but secondary.
- [ ] LIVE / RECONNECTING state is subtle and does not dominate the broadcast.
- [ ] Overlay is comfortably readable at 1280x720.
- [ ] Overlay also scales cleanly at 1920x1080.
- [ ] No horizontal clipping occurs.

## Functional regression
- [ ] First Half starts live without refresh.
- [ ] Score updates live without refresh.
- [ ] Halftime updates live.
- [ ] Second Half updates live.
- [ ] Clock remains within expected precision.
- [ ] Brief disconnect preserves the last-known scoreboard.
- [ ] Reconnect recovers automatically.
- [ ] Hard error is not shown over a valid last-known scoreboard during a temporary outage.
- [ ] No controls are exposed on the overlay.

Automated M11-D validation: PASS / FAIL

Human M11-D acceptance: PASS / FAIL
