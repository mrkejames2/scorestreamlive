# M17-G — Compact Broadcast Overlay & Brand Integration

Parent baseline: `60d9f40` — Complete M17-F match-day workflow and operator polish.

## Locked objective

More field, less overlay — without sacrificing the information a viewer needs.

M17-G is presentation-only. PostgreSQL remains authoritative. Existing Socket.IO recovery, scoring, clock, lifecycle, tenant boundaries, and permissions are unchanged.

## Final M17-G size lock

The approved final Compact target is the smaller **New Compact** presentation:

- approximately 50% of the 1280px canvas width,
- shorter than the first M17-G Compact pass,
- centered and anchored close to the bottom edge of the video,
- clock remains immediately readable,
- team identity and scores remain readable,
- goal/scoring and alert notifications are reduced to match the Compact visual language.

The scoreboard should sit near the bottom of the viewing area rather than floating noticeably above it.

## Locked visual target

The approved M17-G broadcast language includes:

- Compact scoreboard as the default overlay layout.
- Optional Standard layout.
- ScoreStreamLive compact mark integrated into the scoreboard.
- Team logos and team names retained.
- Score and clock remain the dominant information.
- Phase remains directly below the clock.
- Redundant HOME/AWAY labels are removed from the live overlay layouts.
- Smaller scoring notification.
- Smaller alert/broadcast message.
- Smaller score-correction presentation.
- Match-state banners remain visible without dominating the frame.
- Transparent canvas everywhere outside overlay components.

## Overlay URLs

Default / recommended compact mode:

`/overlay/games/<GAME_ID>`

Explicit compact mode:

`/overlay/games/<GAME_ID>?layout=compact`

Optional larger Standard mode:

`/overlay/games/<GAME_ID>?layout=standard`

The query parameter changes presentation only.

## Brand assets

- `static/brand/scorestreamlive-mark.svg` — compact transparent broadcast mark.
- `static/brand/scorestreamlive-logo.png` — supplied master ScoreStreamLive logo retained for product branding and M17-H.

M17-H owns the site-wide navy/orange visual system. M17-G does not recolor the full product.

## Sponsor readiness

Sponsor management is not implemented in M17-G.

The compact scoreboard is intentionally self-contained so future sponsor components can be positioned independently rather than increasing scoreboard size.

## Final event presentation lock

M17-G now uses two distinct scoring-event presentations:

- **Goal recorded:** upper-right GOAL graphic, using the scoring team's branding, team logo/initials, scorer, match minute, and phase. It is temporary and uses the existing goal event flow.
- **Score correction:** lower-left SCORE CORRECTION graphic, styled as a compact orange-accent notification. It remains temporary and uses the existing score-correction event flow.

A normal goal does not use the lower-left correction graphic. A correction does not use the upper-right GOAL graphic.

No new database state, scoring command, Socket.IO contract, or recovery behavior is introduced.

## M17-G visual repair — final Goal and Correction hierarchy

Human Acceptance exposed two presentation defects in the first Goal implementation:

- the legacy Goal DOM was being rearranged with CSS, which caused the ball/GOAL callout, team logo, minute, scorer, and team abbreviation to stack in the wrong visual order;
- the lower-left correction card did not identify which Team the correction affected.

The repaired contract uses explicit markup.

**Goal — upper right:** soccer ball + GOAL! | team logo | scorer, with `minute • phase` beneath. Unknown scorer displays `TEAM GOAL`.

**Score correction — lower left:** `Team Name — correction status`, with `minute • phase` beneath.

These remain presentation-only changes; scoring events, correction events, PostgreSQL authority, Socket.IO delivery, recovery, and timing are unchanged.

## Human acceptance

Validate with real 1280×720 soccer footage and the actual streaming/viewing workflow.

Confirm:

1. Compact is the default.
2. Scoreboard footprint is materially smaller than the pre-M17-G overlay.
3. Home/away logos, team names, score, clock, and phase remain immediately readable.
4. The ScoreStreamLive compact mark is visible but does not compete with team information.
5. Goal/scoring notification is materially smaller and visually consistent with Compact.
6. Broadcast alert is materially smaller and visually consistent with Compact.
7. Score correction remains visible and readable.
8. Standard mode renders correctly with `?layout=standard`.
9. Overlay background remains transparent.
10. No scoring, clock, lifecycle, Socket.IO, or recovery behavior changes.
11. Validate on the resulting YouTube/Streamlabs view, not browser-only.

Acceptance phrase:

`M17-G HUMAN ACCEPTANCE = PASS`
