# Milestone 10-G — Mobile + Tablet Game-Day UX

## Objective

Make the existing Control Center comfortable to operate from the sideline,
using a phone as the primary benchmark and a tablet as the secondary target.

M10-G is a presentation milestone. It does not change the PostgreSQL,
lifecycle, clock, scoring, Socket.IO, or conflict architecture.

## Phone-first changes

- Compact header.
- Three operational status values remain visible in one row.
- Sticky score/clock board is substantially shallower.
- Team names, score, clock and phase fit in one compact scoreboard row.
- Only the lifecycle action relevant to the current phase is shown on narrow
  phones.
- Home/Away scoring controls sit side-by-side on normal phones.
- Very narrow phones fall back to stacked scoring controls.
- Help copy is removed from the game-day path on narrow screens.
- Touch targets remain large.
- iOS form controls stay at 16px to avoid automatic zoom.
- Secondary status/summary/roster information remains available lower on the
  page.
- Footer chrome is hidden on phones.

## Preserved M10-F safety behavior

A displayed button is not necessarily enabled.

Mutation still requires:

```text
socketConnected
AND stateAuthoritative
AND connectionState == LIVE
```

`current-action` is only a presentation class. It cannot bypass the M10-F
mutation readiness gate.

## Human acceptance

Use both an iPhone and a tablet.

### iPhone benchmark

```text
[ ] Score + clock remain visible without consuming most of the screen
[ ] Home and away team names are understandable
[ ] Phase/connection/operator state can be read quickly
[ ] Only the relevant lifecycle action is presented
[ ] Lifecycle button is comfortably tappable
[ ] Both scoring sides are usable without excessive scrolling
[ ] Scorer picker is usable with one hand
[ ] Goal button is difficult to miss-tap
[ ] Scoring Summary remains readable
[ ] Connection/recovery warnings are obvious
[ ] No horizontal scrolling
[ ] Browser does not zoom when scorer selector is tapped
```

### Tablet

```text
[ ] Layout takes advantage of extra width
[ ] No controls feel excessively oversized
[ ] Both scoring panels remain easy to compare
[ ] Score/clock remain prominent
[ ] Rosters and summary remain readable
```

M10-G is accepted only after automated validation and this human checkpoint
both pass.
