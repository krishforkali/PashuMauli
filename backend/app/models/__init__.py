"""PashuMauli models module — import all models so metadata is populated."""
from app.models.animal import Animal
from app.models.audit_log import AuditLog
from app.models.farmer import Farmer
from app.models.geo import Block, District, Village
from app.models.health_case import AIResult, HealthCase
from app.models.user import User, UserRole

__all__ = [
    "Animal",
    "AIResult",
    "AuditLog",
    "Block",
    "District",
    "Farmer",
    "HealthCase",
    "User",
    "UserRole",
    "Village",
]
