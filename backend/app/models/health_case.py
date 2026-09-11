"""SQLAlchemy ORM model for health_cases and ai_results tables."""
import uuid
from datetime import UTC, datetime

from geoalchemy2 import Geography
from sqlalchemy import DateTime, Float, ForeignKey, String
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class HealthCase(Base):
    """Health case entity matching migration 006."""

    __tablename__ = "health_cases"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    client_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True, unique=True
    )
    animal_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("animals.id", ondelete="SET NULL"),
        nullable=True,
    )
    farmer_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("farmers.id", ondelete="SET NULL"),
        nullable=True,
    )
    reported_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    symptoms: Mapped[dict] = mapped_column(JSONB(), nullable=False, default=list)
    suspected_disease: Mapped[str | None] = mapped_column(String(128), nullable=True)
    confidence: Mapped[float | None] = mapped_column(Float(), nullable=True)
    risk_score: Mapped[float | None] = mapped_column(Float(), nullable=True)
    risk_level: Mapped[str] = mapped_column(
        String(32), nullable=False, default="UNKNOWN"
    )
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="OPEN")
    location: Mapped[Geography | None] = mapped_column(
        Geography("POINT", srid=4326), nullable=True
    )
    ai_model_version: Mapped[str | None] = mapped_column(String(64), nullable=True)
    advisory_version: Mapped[str | None] = mapped_column(String(64), nullable=True)
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


class AIResult(Base):
    """AI result entity matching migration 007."""

    __tablename__ = "ai_results"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    case_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("health_cases.id", ondelete="CASCADE"),
        nullable=False,
    )
    model_name: Mapped[str] = mapped_column(String(128), nullable=False)
    model_version: Mapped[str] = mapped_column(String(64), nullable=False)
    input_type: Mapped[str] = mapped_column(String(64), nullable=False)
    predictions: Mapped[dict] = mapped_column(JSONB(), nullable=False, default=dict)
    top_prediction: Mapped[str | None] = mapped_column(String(128), nullable=True)
    confidence: Mapped[float | None] = mapped_column(Float(), nullable=True)
    inference_ms: Mapped[float | None] = mapped_column(Float(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )
