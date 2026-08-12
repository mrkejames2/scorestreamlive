# Game Domain

## Overview

The Game is the first ScoreStreamLive domain entity. It represents a scheduled sporting event and serves as the foundation for future scoreboard, timer, and team functionality.

## Model

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | UUID | Yes | Unique identifier, generated automatically |
| `name` | String(255) | Yes | Human-readable game name |
| `status` | String(20) | Yes | `scheduled`, `live`, `completed`, or `cancelled` |
| `scheduled_at` | DateTime(tz) | No | Optional scheduled start time |
| `created_at` | DateTime(tz) | Yes | Record creation timestamp |
| `updated_at` | DateTime(tz) | Yes | Last modification timestamp |

## Status Lifecycle
