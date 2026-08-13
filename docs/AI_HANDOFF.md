## M6 Finalized Architecture Decisions

The following decisions were approved by GPT architecture review before implementation and are now authoritative:

### 1. `roster:updated` Contract
- **Decision:** Option A — Invalidation notification.
- **Payload:** `{"team_id": "<team-uuid>"}`
- **Rationale:** Clients retrieve authoritative roster via `GET /api/teams/{team_id}/players`. PostgreSQL remains the source of truth.

### 2. `team_id` Mutability
- **Decision:** Immutable during M6.
- **Behavior:** Required at creation. `PATCH /api/players/{player_id}` must reject `team_id` changes.
- **Deferral:** Player transfers are explicitly deferred to a future milestone.

### 3. Jersey Number Uniqueness
- **Decision:** Duplicates permitted.
- **Constraints:** Nullable integer, allowed range 0–999.
- **No:** Global uniqueness or `UNIQUE(team_id, jersey_number)` in M6.

### 4. Roster Ordering
- **Decision:** Deterministic ordering:
  1. `jersey_number` ASC NULLS LAST
  2. `last_name` ASC
  3. `first_name` ASC
  4. `id` ASC

### 5. Event Ordering
- All mutations: Validate → Persist → Commit → Emit.
- Player creation emits `player:created` followed by `roster:updated`.

### 6. Validation Client
- Extended to display `player:created`, `player:updated`, and `roster:updated` events.
- Preserves M3–M5 validation behavior.