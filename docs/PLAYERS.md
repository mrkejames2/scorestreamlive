# Players — Domain Documentation

## Overview

The Player domain represents individual athletes associated with a Team. In Milestone 6, the relationship is intentionally simple:

```
Team (1) → (N) Player
```

A Team's roster is derived directly from the `team_id` foreign key on the Player model.

## Player Model

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | Primary Key | Stable, unique identifier |
| `team_id` | UUID | Foreign Key (teams.id), **Immutable** | The Team this Player belongs to |
| `first_name` | String | Required, nonblank | Player's first name |
| `last_name` | String | Required, nonblank | Player's last name |
| `jersey_number` | Integer | Nullable, 0–999 | Player's jersey number |
| `created_at` | Timestamp | Auto-set | Creation timestamp |
| `updated_at` | Timestamp | Auto-update | Last update timestamp |

## Team Relationship

- `team_id` is **required** at creation.
- `team_id` is **immutable** during Milestone 6.
- Player transfers (changing `team_id`) are explicitly deferred.
- PostgreSQL enforces referential integrity: `players.team_id → teams.id`.

## Jersey Number Rules

- **Nullable:** A Player may not have a jersey number.
- **Allowed Range:** 0–999.
- **Uniqueness:** Duplicate jersey numbers are **permitted**.
  - No global uniqueness constraint.
  - No `UNIQUE(team_id, jersey_number)` constraint in Milestone 6.

## Roster Retrieval

The authoritative roster for a Team is retrieved via REST:

```
GET /api/teams/{team_id}/players
```

**Ordering:** Deterministic, as specified:
1. `jersey_number` ASC NULLS LAST
2. `last_name` ASC
3. `first_name` ASC
4. `id` ASC

## Roster Change Notification

Clients are notified of roster changes via Socket.IO:

- `roster:updated` event (invalidation-only).
- Payload contains only the `team_id`.
- Clients must fetch the full roster via REST.

## REST API

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/players` | Create a new Player |
| GET | `/api/players/{player_id}` | Retrieve a Player |
| PATCH | `/api/players/{player_id}` | Update mutable fields |
| GET | `/api/teams/{team_id}/players` | Retrieve Team roster |

### Mutable Fields (PATCH)
- `first_name`
- `last_name`
- `jersey_number`

### Immutable Fields (PATCH Rejected)
- `id`
- `team_id`
- `created_at`
- `updated_at`

## Validation Rules

| Field | Rule |
|-------|------|
| `team_id` | Must exist, required |
| `first_name` | Required, nonblank, length-limited |
| `last_name` | Required, nonblank, length-limited |
| `jersey_number` | Optional, integer 0–999 |
| `player_id` | Must be valid UUID |

## Socket.IO Events

| Event | Direction | Description |
|-------|-----------|-------------|
| `player:created` | Server → Client | New Player persisted |
| `player:updated` | Server → Client | Player updated |
| `roster:updated` | Server → Client | Team roster changed (invalidation) |

## Design Decisions

1. **No Separate Roster Table:** Roster is derived from `Player.team_id`.
2. **Immutability of `team_id`:** Player transfers deferred to future milestone.
3. **Invalidation-Only Roster Events:** Clients fetch authoritative data via REST.
4. **Jersey Number Permissive:** No uniqueness constraint in M6.
5. **PostgreSQL as Source of Truth:** REST is the mutation boundary; Socket.IO communicates committed state.

## Future Considerations

- Player transfers / `team_id` mutability.
- Jersey number uniqueness constraints.
- Game-specific Player participation.
- Player statistics and scoring events.