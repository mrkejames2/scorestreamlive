# M12-H Human Acceptance — Milestone 12 Final Release Gate

Use the browser UI only. Do not use curl, direct API calls, UUID copying, or database tools.

## Fresh-user flow

- [ ] Open `/games`.
- [ ] Create or select the Home Team.
- [ ] Create or select the Away Team.
- [ ] Verify Team names, short names, colors, and logos/fallbacks.
- [ ] Create the Game from the GUI.
- [ ] Confirm the Game appears in Game Management.
- [ ] Open the Game without copying a UUID.
- [ ] Verify the Game Hub shows the correct teams and authoritative state.
- [ ] Manage Rosters.
- [ ] Add at least one Home Player.
- [ ] Add at least one Away Player.
- [ ] Return to the Game Hub.
- [ ] Verify Home/Away roster counts.
- [ ] Open the Control Center.
- [ ] Open the Broadcast Overlay.
- [ ] Start the First Half.
- [ ] Verify the clock runs on Control Center and Overlay.
- [ ] Record at least one Home goal.
- [ ] Verify Home score changes in Control Center and Overlay.
- [ ] Record at least one Away goal.
- [ ] Verify Away score changes in Control Center and Overlay.
- [ ] End the First Half.
- [ ] Verify Halftime presentation.
- [ ] Start the Second Half.
- [ ] Verify Second Half presentation.
- [ ] End the Game.
- [ ] Verify Full Time presentation and final score.

## Resume / recovery flow

- [ ] Close the browser tabs used for the Game Hub, Control Center, and Overlay.
- [ ] Reopen `/games` in a new browser tab.
- [ ] Find the same Game without browser-history dependence.
- [ ] Open/Review the Game from Game Management.
- [ ] Verify authoritative final score is restored.
- [ ] Verify Full Time lifecycle state is restored.
- [ ] Verify both rosters are restored.
- [ ] Open Control Center again.
- [ ] Open Broadcast Overlay again.
- [ ] Verify both surfaces reconstruct the completed match correctly.

## Product usability gate

- [ ] No terminal commands are required for the normal operator workflow.
- [ ] No UUID needs to be copied manually.
- [ ] No browser localStorage/sessionStorage dependency is required.
- [ ] Navigation between Games, Game Hub, Rosters, Control Center, and Overlay feels coherent.
- [ ] Tablet/mobile-width setup and control surfaces remain usable.
- [ ] Team branding remains readable and consistent.
- [ ] No blocking UX issue prevents a real soccer match demo.

## Final declaration

M12-H HUMAN ACCEPTANCE = PASS

When automated acceptance and this human gate both pass:

MILESTONE 12 HUMAN ACCEPTANCE = PASS
MILESTONE 12 RELEASE CANDIDATE = PASS
