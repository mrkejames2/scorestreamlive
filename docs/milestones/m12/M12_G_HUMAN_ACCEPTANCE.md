# M12-G Human Acceptance — Existing Game Resume / Recovery UX

Use an active Game with at least one Player on each Team and at least one committed Goal.

- [ ] `/games` shows the existing active Game after a fresh browser load.
- [ ] Active Game is clearly marked **RESUMABLE**.
- [ ] Active Game action reads **Resume Game**.
- [ ] Clicking Resume Game opens the correct Game Hub.
- [ ] Game Hub shows **Authoritative State Restored**.
- [ ] Correct Home/Away teams and branding are restored.
- [ ] Correct authoritative score is restored.
- [ ] Correct lifecycle phase is restored.
- [ ] Correct clock status/time is restored.
- [ ] Correct Home/Away roster counts are restored.
- [ ] Active Game Hub action reads **Resume Control Center**.
- [ ] Resume Control Center opens the correct match state.
- [ ] Broadcast Overlay opens with the correct score/clock/branding.
- [ ] Manage Rosters opens the correct authoritative rosters.
- [ ] Close all ScoreStreamLive browser tabs completely.
- [ ] Reopen ScoreStreamLive directly at `/games` without using browser history.
- [ ] Find and resume the Game again with no UUID copy/paste.
- [ ] No browser-local state is required to recover the Game.
- [ ] Refreshing Game Hub re-reads current authoritative state.
- [ ] A completed Game is labeled **COMPLETED** / **Review Game** rather than resumable.
- [ ] Mobile/tablet-width recovery workflow remains usable.

## Optional stronger human recovery test

After the automated M12-G validator has restarted the app container, refresh `/games` and repeat the resume flow. The same Game should remain available.

M12-G HUMAN ACCEPTANCE = PASS / FAIL
