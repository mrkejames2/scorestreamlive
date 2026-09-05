"""Public read-only Game summary projection for M17-C."""

import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.game import Game
from app.models.game_lifecycle import GameLifecycle
from app.models.player import Player
from app.models.scoring_event import ScoringEvent
from app.models.team import Team


class PublicGameSummaryNotFound(Exception):
    """Raised when a requested public Game does not exist."""


def _team_payload(team: Team | None) -> dict[str, Any] | None:
    if team is None:
        return None
    return {
        "id": str(team.id),
        "name": team.name,
        "short_name": team.short_name,
        "logo_url": team.logo_url,
        "primary_color": team.primary_color,
        "secondary_color": team.secondary_color,
    }


def _player_display_name(player: Player | None) -> str:
    if player is None:
        return "Unknown scorer"
    name = " ".join(
        value.strip()
        for value in (player.first_name or "", player.last_name or "")
        if value and value.strip()
    ).strip()
    return name or "Unknown scorer"


def _match_minute(elapsed_seconds: int | None) -> int | None:
    if elapsed_seconds is None:
        return None
    return max(0, int(elapsed_seconds)) // 60 + 1


async def get_public_game_summary(
    db: AsyncSession,
    game_id: uuid.UUID,
) -> dict[str, Any]:
    """Build the authoritative public projection from PostgreSQL."""
    game = await db.get(Game, game_id)
    if game is None:
        raise PublicGameSummaryNotFound("Game not found")

    home_team = await db.get(Team, game.home_team_id) if game.home_team_id else None
    away_team = await db.get(Team, game.away_team_id) if game.away_team_id else None

    lifecycle_result = await db.execute(
        select(GameLifecycle).where(GameLifecycle.game_id == game_id)
    )
    lifecycle = lifecycle_result.scalar_one_or_none()
    phase = lifecycle.phase if lifecycle is not None else "pregame"

    events_result = await db.execute(
        select(ScoringEvent)
        .where(
            ScoringEvent.game_id == game_id,
            ScoringEvent.event_type == "goal",
        )
        .order_by(
            ScoringEvent.game_elapsed_seconds.asc().nulls_last(),
            ScoringEvent.created_at.asc(),
            ScoringEvent.id.asc(),
        )
    )
    events = list(events_result.scalars().all())

    player_ids = {event.player_id for event in events if event.player_id is not None}
    players: dict[uuid.UUID, Player] = {}
    if player_ids:
        player_result = await db.execute(
            select(Player).where(Player.id.in_(player_ids))
        )
        players = {player.id: player for player in player_result.scalars().all()}

    scoring_events = []
    for event in events:
        player = players.get(event.player_id) if event.player_id is not None else None
        if event.team_id == game.home_team_id:
            team_side = "home"
        elif event.team_id == game.away_team_id:
            team_side = "away"
        else:
            team_side = "unknown"

        scoring_events.append(
            {
                "id": str(event.id),
                "team_id": str(event.team_id),
                "team_side": team_side,
                "player_id": str(event.player_id) if event.player_id else None,
                "scorer_name": _player_display_name(player),
                "jersey_number": player.jersey_number if player is not None else None,
                "game_elapsed_seconds": event.game_elapsed_seconds,
                "minute": _match_minute(event.game_elapsed_seconds),
            }
        )

    return {
        "game": {
            "id": str(game.id),
            "name": game.name,
            "scheduled_at": game.scheduled_at,
            "home_score": int(game.home_score),
            "away_score": int(game.away_score),
            "phase": phase,
            "is_final": phase == "full_time",
            "archived": game.archived_at is not None,
        },
        "home_team": _team_payload(home_team),
        "away_team": _team_payload(away_team),
        "scoring_events": scoring_events,
    }
