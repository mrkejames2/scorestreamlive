
## Scoreboard Template / Theme Selection

Add a configurable scoreboard template system that allows users to select the visual presentation used for ScoreStreamLive displays without changing the underlying game-control workflow.

### Broadcast Overlay Templates
- Allow authorized users to choose from multiple scoreboard overlay templates.
- Templates may vary in:
  - Layout and positioning
  - Scoreboard size
  - Team logo presentation
  - Team name presentation
  - Clock and phase presentation
  - Goal/scoring animations
  - Sponsor Zone placement
  - Club branding placement
  - Color treatment and overall visual style
- Preserve the existing overlay design as a default/classic template.
- Template selection should not affect authoritative game state, scoring, clock, lifecycle, or sponsor tracking.

### Venue Scoreboard Templates
- Allow authorized users to choose from multiple Venue Scoreboard designs.
- Preserve the M19 HF4 Venue Scoreboard as the default/classic template.
- Potential templates could be optimized for:
  - TVs
  - Projectors
  - Large venue displays
  - Scoreboard/LED-style presentation
  - Different sports
- Venue templates should continue to consume the same authoritative game state and Socket.IO updates.

### Configuration
- Broadcast Overlay and Venue Scoreboard templates should be independently selectable.
- Consider club-level defaults with optional per-game overrides.
- Template selection should reference a template identifier rather than duplicate presentation code/configuration per game.
- Future multi-sport support should allow sport-specific templates while retaining a common template framework.

### Future Considerations
- Template preview before selection.
- Custom club colors and branding within compatible templates.
- Premium/custom templates as a possible future subscription entitlement.
- User-created or organization-specific templates may be considered later, but are not required for the initial implementation.
