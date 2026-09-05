# M17-B — Team & Game Lifecycle Management

## Objective
Allow authorized Club users to clean up accidental resources without destroying meaningful roster or match history.

## Lifecycle policy
- `archived_at IS NULL` means operational/active.
- `archived_at IS NOT NULL` means archived.
- Normal Team/Game list APIs exclude archived resources.
- `?archived=true` returns archived resources.
- Archive and restore are explicit operations independent of Game `status`.

## Hard-delete policy
A Game may be permanently deleted only while pristine: scheduled, zero score, no scoring events, no persisted clock, and no persisted match lifecycle. GameOperator assignments are administrative and are removed transactionally.

A Team may be permanently deleted only when it has no players, no Game references, and no scoring history. TeamManager assignments are administrative and are removed transactionally.

Resources with durable history return HTTP 409 and must be archived.

## Authorization
DIRECTOR: lifecycle-manage same-Club Teams/Games.
MANAGER: lifecycle-manage resources already permitted by current Team/Game authorization.
OPERATOR: cannot archive, restore, or delete Teams/Games.
Cross-Club direct IDs remain masked by existing authorization as not found.

## Migration
Revision `20260904_0014` follows `20260902_0013` and adds nullable `archived_at` timestamps plus Club/archive indexes.

## Human acceptance
1. Create a disposable Team and permanently delete it.
2. Confirm a Team with roster/game history returns 409 on DELETE, then archive it.
3. Confirm archived Team disappears from normal list and appears with `?archived=true`.
4. Restore it and confirm it returns to the normal list.
5. Create a disposable scheduled Game and permanently delete it.
6. Confirm a Game with match history returns 409 on DELETE, then archive it.
7. Confirm archived Game disappears from normal list and appears with `?archived=true`.
8. Restore it and confirm historical score/state remains intact.
9. Confirm an OPERATOR cannot use lifecycle endpoints.
10. Confirm cross-Club IDs remain hidden.
11. Confirm normal public Overlay behavior remains unchanged.
