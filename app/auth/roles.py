"""Minimal M15 club roles."""
from enum import Enum

class ClubRole(str, Enum):
    DIRECTOR = "DIRECTOR"
    MANAGER = "MANAGER"
    OPERATOR = "OPERATOR"
