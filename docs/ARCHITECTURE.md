## Domain Model — Milestone 6 (Players / Rosters)

### Player Entity
- Represents an individual athlete.
- Belongs to exactly one Team (`team_id` foreign key).
- Fields: `id`, `team_id`, `first_name`, `last_name`, `jersey_number`, `created_at`, `updated_at`.

### Team Roster
- A Team's roster is derived from Players with `team_id = Team.id`.
- No separate `Roster` table exists in Milestone 6.
- Roster changes are propagated via `roster:updated` (invalidation-only).

### Relationship Diagram
```
Game
  │
  ├── home_team_id ──► Team (1)
  │                     │
  │                     └── Players (N)
  │
  └── away_team_id ──► Team (2)
                        │
                        └── Players (N)
```

### Key Architectural Decisions
1. **Roster as a Query:** No separate roster table. `SELECT * FROM players WHERE team_id = ?`.
2. **Roster Change Propagation:** Invalidation-only (`roster:updated` with `team_id`). Clients refetch via REST.
3. **`team_id` Immutability:** Player transfers are deferred. `team_id` is set at creation and never changed in M6.
4. **Jersey Numbers:** Nullable, range 0–999, duplicates permitted.

### Data Flow
```
POST /api/players
  ↓
Player Service
  ↓
PostgreSQL (INSERT)
  ↓
COMMIT
  ↓
Socket.IO:
  1. player:created (full Player payload)
  2. roster:updated ({"team_id": "..."})
```

### REST API Boundaries
- **Players:** CRUD (create, read, update; no delete).
- **Rosters:** Read-only via `GET /api/teams/{team_id}/players`.

### Socket.IO Event Flow
- `player:created` → Full Player payload.
- `player:updated` → Full updated Player payload.
- `roster:updated` → Invalidation notification (only `team_id`).

All events are emitted **after** successful database commit.