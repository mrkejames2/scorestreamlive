# M12-D6 Human Acceptance / M12-D Final Human Gate

Use a branded Game with distinct Home/Away colors and preferably two logos.

## Broadcast branding

- [ ] Home logo or initials fallback appears in the scoreboard.
- [ ] Away logo or initials fallback appears in the scoreboard.
- [ ] Home primary/secondary colors render correctly.
- [ ] Away primary/secondary colors render correctly.
- [ ] Team names/short names remain readable.
- [ ] Scores remain prominent.
- [ ] Clock remains prominent.
- [ ] Phase remains readable.
- [ ] Transparent OBS/Streamlabs background is preserved.

## Match operation

- [ ] Control Center and Overlay remain synchronized within accepted M11-F tolerance.
- [ ] Start First Half updates the Overlay.
- [ ] Home Goal updates score and shows branded Home goal banner.
- [ ] Away Goal updates score and shows branded Away goal banner.
- [ ] Goal scorer/minute presentation still works.
- [ ] End First Half shows Halftime presentation.
- [ ] Start Second Half updates Overlay correctly.
- [ ] End Game shows Full Time presentation.
- [ ] Refreshing Overlay does not replay stale lifecycle banners.
- [ ] Socket reconnect/recovery keeps last-known state and resumes authoritative sync.

## Fallback / responsive

- [ ] A Team without a logo shows initials instead of a broken image.
- [ ] 1280px / 720p broadcast layout remains clean.
- [ ] Narrow preview remains usable with no overlap or clipping.

M12-D6 HUMAN ACCEPTANCE = PASS / FAIL

When all D1-D6 human gates and the final automated gate are green:

M12-D HUMAN ACCEPTANCE = PASS / FAIL
