# ScoreStreamLive — Product Roadmap

> **Repository source of truth for milestone planning**
>
> Last reconciled: 2026-10-01  
> Current production baseline before this documentation-only update: `40814c2`  
> Current production migration: `20261001_0036`

## Current Product State

ScoreStreamLive has completed the original production foundation and the major M18/M19 expansion work.

| Milestone | Focus | Status |
|---|---|---|
| M0–M14 | Core platform, scoring, clock, lifecycle, overlay, game setup, teams/rosters, Game Library | COMPLETE |
| M15 | Authentication, Accounts & Ownership | COMPLETE |
| M16 | Production MVP Hardening | COMPLETE |
| M17 | Sharing / Public Game Experience | COMPLETE |
| M18 | Billing, Entitlements, Signup, Checkout & Production Readiness | COMPLETE |
| M19 | Sponsor, Advertising & Broadcast Presentation | COMPLETE |
| M19-HF8 | Advertisement Artwork Library Integration | PRODUCTION ACCEPTANCE PASS |

### M19 final production capabilities

M19 ultimately absorbed substantially more broadcast/presentation work than the earlier roadmap anticipated. Production now includes:

- sponsor library and sponsor assignment
- sponsor presentation and reporting foundations
- Director / Manager / Operator role semantics
- reusable Broadcast Artwork Library
- Welcome / Intro artwork
- Thank You artwork
- Advertisement broadcast scene
- reusable Advertisement artwork
- Halftime Slideshow
- Summary scene
- independent Venue Scoreboard display
- game-control operational workflow refinements

Because these capabilities were pulled forward, future milestone scope should not duplicate them.

---

# Remaining Roadmap

## M20 — Analytics, Observability & Support

**Status: PLANNED**

### Objective

Make ScoreStreamLive operationally understandable and supportable as real customers begin using the SaaS.

### Planned scope

- product usage analytics
- operational observability
- application/error visibility
- deployment and runtime diagnostics
- customer/support diagnostics
- club/game activity visibility
- billing/signup funnel visibility where appropriate
- support tooling that helps diagnose customer problems without crossing tenant boundaries
- production reliability and operational reporting

### Product outcome

ScoreStreamLive should answer questions such as:

- Is the platform healthy?
- What are customers actually using?
- Where are users encountering failures?
- What happened during a specific game/session?
- Can a support issue be diagnosed quickly and safely?
- Are signup, onboarding, billing, and game-operation workflows succeeding?

M20 is about operating the SaaS reliably, not adding another broadcast presentation feature.

---

## M21 — Sponsorship & Monetization Expansion

**Status: PLANNED**

### Objective

Build on the M19 sponsor/advertising foundation and turn sponsorship into a more complete club/customer capability.

### Existing foundation from M19

Already complete and should **not** be rebuilt:

- Sponsor Library
- sponsor artwork
- game sponsor assignment
- sponsor presentation
- Advertisement scene
- reusable Broadcast Artwork Library
- Halftime Slideshow
- sponsor reporting/impression foundations already present

### Remaining direction

Candidate M21 capabilities from the settled roadmap include:

- sponsor packages
- sponsor schedules
- start/end or expiration rules
- placement rules
- sponsor exposure/impression reporting
- game-level and multi-game sponsor reporting
- business-facing sponsor reports
- QR codes / sponsor links
- campaign-style sponsor management
- stronger club-level monetization workflows

### Product boundary

ScoreStreamLive remains a SaaS platform for clubs, teams, parents, and stream operators to run **their own** broadcasts and sponsorships. ScoreStreamLive itself is not promising a sponsor placement across all customer streams.

---

## M22 — Club / Organization Management

**Status: PLANNED**

### Objective

Strengthen ScoreStreamLive as a whole-club / organization platform rather than only a collection of independently operated games.

### Planned direction

- richer Club Director administration
- organization-wide team/game visibility
- stronger manager delegation
- club-level operational workflows
- user/member administration improvements
- organization-wide settings
- scalable club structures
- club-level reporting
- onboarding improvements for larger organizations
- administration workflows that preserve `club_id` as the tenant boundary

### Existing foundation

M15/M19 already established authentication, club membership, Director/Manager/Operator roles, tenant isolation, and broad Manager game/team operations. M22 should extend that foundation rather than replace it.

---

## M23 — Multi-Sport Platform Foundation

**Status: PLANNED**

### Objective

Generalize the mature soccer implementation into a sport-aware platform capable of supporting multiple sports without creating separate applications.

### Planned sports

The long-term sport list includes:

- basketball
- baseball
- football
- hockey
- futsal
- lacrosse
- tennis
- bowling

### Planned architectural direction

- sport/rules abstraction
- sport-specific scoring models
- sport-specific clock/timing behavior
- sport-specific periods/innings/quarters/sets
- sport-specific game lifecycle
- configurable scoreboard presentation
- shared game/team/account infrastructure wherever practical
- preserve the existing soccer implementation as a validated sport rather than destabilizing it

### Product outcome

A club should be able to use ScoreStreamLive for more than soccer while the common SaaS, account, broadcast, artwork, sponsorship, and operational infrastructure remains shared.

---

## M24 — Growth & Advanced Features

**Status: PLANNED**

### Objective

Expand the mature SaaS with higher-level capabilities that improve scale, automation, integration, and customer value.

### Roadmap direction

This phase has intentionally remained broader than M20–M23. Candidate areas include:

- workflow automation
- external integrations
- advanced statistics
- richer reporting
- larger-organization capabilities
- improved broadcast workflows
- customer growth/retention features
- advanced administrative tooling

Detailed M24 architecture must be approved before implementation. Items should move here only after the core operational, monetization, organization, and multi-sport foundations are stable.

---

## M25 — Final Advanced / Growth Phase

**Status: PLANNED — EXACT PRIOR SCOPE REQUIRES RECOVERY**

The historical planning discussions explicitly extended the roadmap through **M25**, but the exact previously agreed M25 title and detailed scope have not been recovered with enough confidence to record them as fact.

**Do not silently redefine M25.**

When the original M25 definition is recovered, replace this section with the exact agreed scope and preserve the change in Git history.

Until then, M25 remains a reserved roadmap milestone rather than an invented specification.

---

# Deferred / Cross-Milestone Work

These items are known outstanding work but are not automatically assigned to a milestone merely by appearing here.

## Stripe end-to-end production validation

M18 billing architecture and production readiness passed, but the final Stripe Test Mode end-to-end transaction exercise remains a validation item.

## Broadcast / Venue Scoreboard Template Selection

Backlog item recorded previously in Git.

Future direction:

- selectable broadcast overlay templates
- selectable Venue Scoreboard templates
- preserve underlying game/scoring authority
- presentation selection independent from game state

## Broadcast Artwork Library Management Polish

HF6–HF8 established the reusable library and API behavior. Additional Director-facing library management UX may be improved independently where needed.

---

# Roadmap Governance

This file is the repository source of truth for ScoreStreamLive milestone sequencing.

Rules:

1. Roadmap changes should be committed to Git.
2. Do not rely on chat history as the only record of milestone scope.
3. A roadmap entry describes planned direction; it is not automatic authorization to implement.
4. Before beginning a milestone, define and approve its detailed architecture and acceptance boundary.
5. If work is pulled forward into an earlier milestone/hotfix, update this roadmap so future milestones do not duplicate it.
6. Preserve `club_id` tenant isolation across all future work.
7. Production deployment remains a deliberate release gate.
8. Deferred enhancements belong in `BACKLOG.MD` or the appropriate milestone document.
9. Do not invent missing historical milestone definitions; mark them for recovery and reconcile them through a Git commit.

---

# Next Milestone

```text
M20 — Analytics, Observability & Support
STATUS: NEXT / PLANNED
```

Before implementation, M20 should receive its own architecture document and explicit scope/acceptance approval.
