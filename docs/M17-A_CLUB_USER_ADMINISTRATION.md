# M17-A — Club User Administration & Lifecycle Safety

## Objective

Allow a Club Director to safely administer existing Club users, roles, account
status, Team Manager assignments, and Game Operator assignments without database
or CLI intervention.

M17-A extends the existing M15 Director administration foundation. It does not
introduce a new authorization model or database schema.

## Delivered behavior

- Director-only same-Club member list and member detail API.
- Director-only role changes between DIRECTOR, MANAGER, and OPERATOR.
- Active/inactive account lifecycle management.
- Immediate server-side session revocation when a member is deactivated.
- Server invariant: every Club retains at least one active Director.
- Role-transition cleanup:
  - MANAGER removes GameOperator rows.
  - OPERATOR removes TeamManager rows.
  - DIRECTOR removes both explicit assignment types because Directors have
    Club-wide authority.
- Inactive users cannot receive new TeamManager or GameOperator assignments.
- Existing temporary-password member creation remains unchanged for compatibility.
  M17-D owns invitation/activation replacement.
- Existing People & Access account UI now includes member management controls.
- Cross-Club user direct IDs are masked as not found.
- Public Overlay behavior remains unchanged.

## Schema

No Alembic migration is required.

The implementation reuses:

- users.club_id
- users.club_role
- users.is_active
- team_managers
- game_operators
- user_sessions

## Validation

M17-A adds `Club User Administration` as the 26th regular validation domain.

Local validation uses disposable M15-E tenant fixtures and validates:

- Director access.
- Manager/Operator denial.
- unauthenticated denial.
- cross-Club direct-ID masking.
- last active Director protections.
- safe Director promotion/demotion.
- incompatible assignment cleanup.
- session revocation on deactivation.
- reactivation.
- inactive assignment rejection.
- public Overlay regression.

Production validation is non-destructive and performs structural checks plus
logged-out authorization verification.

## Human acceptance

1. Sign in as a Director and open `/account`.
2. Confirm Club Members display role, status, and current assignments.
3. Open Manage for a Manager and change the role to Operator.
4. Confirm the warning describes assignment cleanup and the change succeeds.
5. Confirm the former Manager no longer has Team Manager assignments.
6. Change an Operator to inactive and confirm the account immediately loses
   authenticated access.
7. Reactivate the account and confirm login works again.
8. Attempt to deactivate/demote the only active Director and confirm it is blocked.
9. Promote a second member to Director; then confirm the original Director may
   be demoted.
10. Confirm Manager and Operator accounts cannot access Club administration.
11. Confirm a logged-out public Overlay still loads normally.

M17-A is complete only after FAST, FULL, and Human Acceptance all PASS.
