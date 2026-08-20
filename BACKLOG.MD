# ScoreStreamLive Enhancement Backlog

This file records enhancement ideas intentionally deferred so they do not expand the scope of an active milestone.

## Team Management

- Edit Teams

## Player Management

- Edit Players

## Validation / Test Data Maintenance

- Add a safe validation/test-data cleanup strategy. Current cumulative milestone validation creates persistent Teams, Games, Players, scoring events, clocks, and lifecycle records that can accumulate over time. Design cleanup so validation-created records can be identified and removed safely without risking real user/application data. Do not mix this work into M13 unless explicitly authorized.
- Add a deliberate application data reset/cleanup procedure so ScoreStreamLive can be returned to a clean, fresh-data baseline before real use. Preserve schema/migrations and required application structure while safely removing accumulated development, validation, and test records and associated uploaded test assets. Keep this separate from automatic validation cleanup so a full reset requires an intentional operator action.

---

Last reviewed: Milestone 13-G
