# M17-H — Cohesive Product Theme & UI Consistency

Parent baseline: `5cb947c` — Complete M17-G compact broadcast overlay and brand integration.

## Locked objective

Make ScoreStreamLive look and feel like one coherent product while preserving all application behavior.

M17-H is presentation/design-system only.

No database model, Alembic migration, authorization rule, tenant boundary, scoring command,
clock rule, lifecycle rule, Socket.IO contract, or recovery behavior is changed.

## Canonical brand

The user-supplied ScoreStreamLive logo is the canonical product logo.

Primary visual system:

- deep navy: `#0b2435`
- orange: `#fe6505`
- white / near-white primary application surfaces
- cool neutral grays for metadata, borders, and secondary copy

The visual direction is a clean sports/broadcast SaaS product:
light application shell, navy structure/navigation, and orange action/live emphasis.

## Scope

M17-H applies one shared design system to:

- authentication and account recovery
- account / Club administration
- games / dashboard / setup / detail
- teams / roster management
- match-day control
- post-game summary / broadcast surfaces
- navigation
- buttons
- forms
- cards and panels
- tables
- badges / statuses / messages
- responsive presentation
- keyboard focus / reduced-motion behavior

Team-specific colors remain scoped to Team/Game identity.

## M17-G preservation

The M17-G public overlay remains isolated from the global application theme.

M17-H adds version query strings to the M17-G overlay CSS/JS assets so a deployment
cannot silently leave an older cached overlay runtime active in the browser.

## Human acceptance

Verify desktop and mobile-width views.

Confirm:

1. ScoreStreamLive navy/orange branding is immediately recognizable.
2. Login/recovery screens use the canonical full logo.
3. Navigation consistently uses the compact brand mark.
4. Games, Teams, Account, Control, Summary, and setup/detail surfaces share the same visual language.
5. Primary actions are orange and secondary actions remain visually quieter.
6. Forms have consistent borders, focus states, and spacing.
7. Cards/panels/tables use consistent white surfaces, navy text, and neutral borders.
8. Team-specific colors remain visible where Team/Game branding is intended.
9. The M17-G broadcast overlay remains visually and functionally unchanged.
10. Refreshing after a deployment loads the versioned overlay assets without requiring a manual hard refresh.
11. No scoring, clock, lifecycle, Socket.IO, authorization, or recovery behavior changes.

Acceptance phrase:

`M17-H HUMAN ACCEPTANCE = PASS`
