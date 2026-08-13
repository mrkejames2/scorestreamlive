# Team Domain

## Overview

The Team is a persistent domain entity representing a sports team. Games reference Teams as Home and Away opponents through foreign-key relationships.

## Model

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | UUID | Yes | Unique identifier |
| `name` | String(255) | Yes | Full team name |
| `short_name` | String(100) | No | Concise display name for scoreboards |
| `created_at` | DateTime(tz) | Yes | Creation timestamp |
| `updated_at` | DateTime(tz) | Yes | Last modification timestamp |

## REST API

### Create Team
```text
POST /api/teams