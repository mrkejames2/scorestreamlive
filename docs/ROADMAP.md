# ScoreStreamLive — Product Roadmap

## Product Transition

Milestones through M10 established the core engine and operator cockpit. M11 onward increasingly builds the product a parent, coach, streamer, or club uses directly.

## Completed Foundation

```text
M0–M9   Core deployment, persistence, real-time, domain, scoring, clock, lifecycle
M10     Control Center / operator cockpit
M11     Live Scoreboard Overlay
M12     Game Setup / Pre-Game Workflow
```

All milestones M0–M12 are complete as of the current baseline.

## Product Roadmap

| Milestone | Focus | What becomes visible/useful |
|---|---|---|
| **M13** | **Team & Roster Management UI** | Manage teams, players, colors, logos |
| **M14** | **Game Library / Dashboard** | See upcoming, live, and completed games |
| **M15** | **Accounts & Ownership** | Users, login, permissions, game ownership |
| **M16** | **Production MVP Hardening** | Security, cleanup, deployment, production acceptance |
| **M17** | **Sharing & Public Game Experience** | Public scoreboard/game pages and shareable links |
| **M18** | **Monetization Foundation** | Plans, subscriptions, sponsor/ad capabilities |
| **M19+** | **Sport Engine Expansion** | Basketball, hockey, football, baseball, and additional sports |

## M13 Direction

M13 is the next major milestone:

```text
Team & Roster Management UI
```

Expected high-level decomposition, subject to architecture approval at M13 start:

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

The purpose of M13 is to make existing Team/Player/Roster/branding capabilities maintainable through first-class product UI. It should not absorb Game Library/Dashboard work intended for M14 or redesign the validated match engine.

## Roadmap Governance

Roadmap entries describe direction, not automatic authorization.

Before each major milestone:

```text
read current repository documentation
inspect actual implementation
approve milestone architecture
approve sub-milestone boundaries
then implement
```

Deferred enhancements are tracked in root `BACKLOG.MD`.
