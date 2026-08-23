"""SQLAlchemy domain models.

Import model classes here so SQLAlchemy string-based relationships resolve
consistently in the web application, standalone CLI commands, and validation.
"""

from app.models.club import Club
from app.models.user import User
from app.models.user_session import UserSession
from app.models.team import Team
from app.models.player import Player
from app.models.game import Game
from app.models.scoring_event import ScoringEvent
from app.models.game_clock import GameClock
from app.models.game_lifecycle import GameLifecycle
from app.models.team_manager import TeamManager
from app.models.game_operator import GameOperator

__all__ = [
    "Club",
    "User",
    "UserSession",
    "Team",
    "Player",
    "Game",
    "ScoringEvent",
    "GameClock",
    "GameLifecycle",
    "TeamManager",
    "GameOperator",
]
