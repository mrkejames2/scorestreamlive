# M17-F — Match-Day Workflow & Operator Polish

## Objective
Make the ScoreStreamLive Control Center safe, obvious, fast, and confidence-inspiring for an authorized Manager or Operator running a real soccer match from Pregame through Full Time, while preserving PostgreSQL authority, Socket.IO recovery behavior, tenant isolation, and match-history integrity.

## Locked architecture
- Existing Control Center remains the match-day operational hub.
- PostgreSQL/server-side state remains authoritative.
- REST/service transactions remain the mutation boundary.
- Socket.IO remains transport/change notification, not authority.
- Reconnect/recovery reconciles from authoritative state.
- No authorization redesign, new event store, or M17-F database migration.
- Existing lifecycle confirmation and in-flight duplicate protections are preserved.
- M17-G owns production supportability; M17-H overlay sizing; M17-I cohesive theming.

## In scope
Pregame readiness, state-aware primary action, archived/Full-Time read-only behavior, recent scoring activity, Full-Time links to Public Summary/Broadcast Scene, phone/tablet operator polish, and regression domain #31.

## Out of scope
Overlay sizing, global theming, support diagnostics, MFA, billing, multi-Club, new sports, distributed brokers/queues, microservices, framework migration, major lifecycle rewrite, reopening completed games, analytics.

## Acceptance
FAST and FULL must report 31/31 PASS, followed by a short real-game Human Acceptance using an authorized Manager or Operator. Final acceptance text: `M17-F HUMAN ACCEPTANCE = PASS`.
