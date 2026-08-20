# ScoreStreamLive — Product Roadmap

## Completed Foundation

```text
M0–M9   Core deployment, persistence, real-time, domain, scoring, clock, lifecycle
M10     Control Center / operator cockpit
M11     Live Scoreboard Overlay
M12     Game Setup / Pre-Game Workflow
```

M0–M12 are production complete.

## Current Release Candidate

```text
M13 — Team & Roster Management UI
```

M13 implementation is complete and has passed its local release gate and human acceptance. Production deployment/validation remains before M13 can be declared fully complete.

Delivered M13 decomposition:

```text
M13-A — Team Management Home
M13-B — Team Create / Edit / Branding
M13-C — Team Detail & Roster View
M13-D — Player Create / Edit
M13-E — Roster Management UX
M13-F — Management UX Polish / Mobile
M13-G — Recovery / Persistence / Regression
M13-H — Final Acceptance / Release Gate
```

M13 makes existing Team/Player/Roster/branding capabilities maintainable through first-class product UI while preserving the validated match engine.

## Product Roadmap

| Milestone | Focus | Product outcome |
|---|---|---|
| **M13** | **Team & Roster Management UI** | Local/human accepted; production release pending |
| **M14** | **Game Library / Dashboard** | See upcoming, live, and completed games |
| **M15** | **Accounts & Ownership** | Users, login, permissions, game ownership |
| **M16** | **Production MVP Hardening** | Security, cleanup, deployment, production acceptance |
| **M17** | **Sharing & Public Game Experience** | Public scoreboard/game pages and shareable links |
| **M18** | **Monetization Foundation** | Plans, subscriptions, sponsor/ad capabilities |
| **M19+** | **Sport Engine Expansion** | Basketball, hockey, football, baseball, additional sports |

## Next Direction

After M13 production closure:

```text
M14 — Game Library / Dashboard
```

M14 should make persisted Games easier to find and understand as upcoming, live, or completed. Detailed M14 scope remains subject to repository inspection and architecture approval at the start of the M14 session.

## Governance

Roadmap entries describe direction, not automatic authorization. Deferred enhancements remain in root `BACKLOG.MD`.
