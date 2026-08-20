# M12-A Human Acceptance — Game Management Home

## Entry point
- [ ] `/games` loads without knowing a UUID.
- [ ] Page feels like the normal starting point for ScoreStreamLive.
- [ ] Existing games are visible.
- [ ] Refresh works.

## Game cards
- [ ] Game name is readable.
- [ ] Home and Away teams are correct.
- [ ] Authoritative score is correct.
- [ ] Phase is correct.
- [ ] Clock state is understandable.
- [ ] Games without lifecycle/clock do not break the page.
- [ ] Game ID is visible for diagnostics but not required for normal use.

## Navigation
- [ ] Open Control Center opens the correct game.
- [ ] Open Overlay opens the correct game.
- [ ] No shell command or copied UUID is needed to navigate to either.

## Guardrails
- [ ] M12-A does not create/update/delete games.
- [ ] M12-A does not perform client-side score arithmetic.
- [ ] M12-A does not introduce clock:tick.
- [ ] M11-G regression remains green.

Automated M12-A validation: PASS / FAIL

Human M12-A acceptance: PASS / FAIL
