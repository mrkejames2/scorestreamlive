# ScoreStreamLive Enhancement Backlog

This file records enhancement ideas intentionally deferred so they do not expand the scope of an active milestone.

## Team Management

- Improve `/teams` discoverability for large datasets. Development/validation has produced 1000+ Teams, making it difficult to find a Team with roster data. Consider search/filtering, useful roster/player counts, and/or pagination as part of an appropriately scoped future UX milestone.

## Player Management

- Player transfer between Teams remains deferred.
- Player deletion remains deferred.

## Validation / Test Data Maintenance

- Add a safe validation/test-data cleanup strategy. Current cumulative milestone validation creates persistent Teams, Games, Players, scoring events, clocks, lifecycle records, branding, and uploaded test assets that can accumulate over time. Design cleanup so validation-created records can be identified and removed safely without risking real user/application data.
- Add a deliberate application data reset/cleanup procedure so ScoreStreamLive can be returned to a clean, fresh-data baseline before real use. Preserve schema/migrations and required application structure while safely removing accumulated development, validation, and test records and associated uploaded test assets. Keep this separate from automatic validation cleanup so a full reset requires an intentional operator action.

## Broadcast Operations

- Add a permanent/stable broadcast endpoint (for example, `/stream/live`) that can be configured once as the browser-source URL in Streamlabs/OBS. From the ScoreStreamLive Control Center, allow an authorized operator to assign or switch the game currently routed to that endpoint (for example, a **Make This Game Live** action). The permanent endpoint should then display the assigned game's existing broadcast scene—Intro, Live, Summary, or Thank You—without requiring the browser-source URL to change.
  - Primary use case: tournament/game-day workflows where there may be only about 10 minutes between games and changing a game-specific browser-source URL in Streamlabs Mobile is cumbersome.
  - Goal: configure Streamlabs once, then manage both the active game and its broadcast scene entirely from ScoreStreamLive.
  - Preserve game-specific scene state and sponsor/tracking behavior while introducing an account/club-level active-game routing layer.
  - Consider safe handoff behavior when switching games, including what viewers see when no game is assigned and protection against accidental reassignment during a live broadcast.

---

Last reviewed: M19 production hotfix / broadcast operations backlog update
