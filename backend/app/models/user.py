"""SQLAlchemy ORM model for users table."""
import uuid
from datetime import UTC, datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class UserRole(str, Enum):
    FARMER = "FARMER"
    FIELD_VET = "FIELD_VET"
    DISTRICT_OFFICER = "DISTRICT_OFFICER"
    STATE_ADMIN = "STATE_ADMIN"
    LAB_USER = "LAB_USER"
    SYSTEM_ADMIN = "SYSTEM_ADMIN"


class User(Base):
    """User entity matching migration 002."""

    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[str] = mapped_column(String(32), nullable=False, unique=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(64), nullable=False)
    preferred_language: Mapped[str] = mapped_column(
        String(16), nullable=False, default="en"
    )
    village_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean(), nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
