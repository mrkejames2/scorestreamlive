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

---

Last reviewed: Milestone 13-H documentation synchronization
