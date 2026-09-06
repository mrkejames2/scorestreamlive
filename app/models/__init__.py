"""SQLAlchemy domain models.

Import model classes here so SQLAlchemy string-based relationships resolve
consistently in the web application, standalone CLI commands, and validation.
"""

from app.models.club import Club
from app.models.user import User
from app.models.user_session import UserSession
from app.models.user_invitation import UserInvitation
from app.models.user_password_reset import UserPasswordReset
from app.models.team import Team
from app.models.player import Player
from app.models.game import Game
from app.models.scoring_event import ScoringEvent
from app.models.game_clock import GameClock
from app.models.game_lifecycle import GameLifecycle
from app.models.team_manager import TeamManager
from app.models.game_operator import GameOperator
from app.models.plan import Plan, Entitlement, PlanEntitlement
from app.models.subscription import Subscription
from app.models.billing_external_reference import BillingExternalReference
from app.models.billing_event import BillingEvent

__all__ = [
    "Club",
    "User",
    "UserSession",
    "UserInvitation",
    "UserPasswordReset",
    "Team",
    "Player",
    "Game",
    "ScoringEvent",
    "GameClock",
    "GameLifecycle",
    "TeamManager",
    "GameOperator",
    "Plan",
    "Entitlement",
    "PlanEntitlement",
    "Subscription",
    "BillingExternalReference",
    "BillingEvent",
]
