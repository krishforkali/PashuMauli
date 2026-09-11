"""SQLAlchemy ORM models for districts, blocks, villages."""
import uuid

from geoalchemy2 import Geography
from geoalchemy2.elements import WKBElement
from sqlalchemy import ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import BaseModel


class District(BaseModel):
    """Administrative district model."""

    __tablename__ = "districts"

    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    state: Mapped[str] = mapped_column(String(255), nullable=False, default="Maharashtra")
    geometry: Mapped[WKBElement | None] = mapped_column(
        Geography("MULTIPOLYGON", srid=4326), nullable=True
    )

    blocks: Mapped[list["Block"]] = relationship("Block", back_populates="district", cascade="all, delete-orphan")


class Block(BaseModel):
    """Tehsil / Taluka / Block model."""

    __tablename__ = "blocks"

    district_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("districts.id", ondelete="CASCADE"), nullable=False, index=True
    )
    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    geometry: Mapped[WKBElement | None] = mapped_column(
        Geography("MULTIPOLYGON", srid=4326), nullable=True
    )

    district: Mapped["District"] = relationship("District", back_populates="blocks")
    villages: Mapped[list["Village"]] = relationship("Village", back_populates="block", cascade="all, delete-orphan")


class Village(BaseModel):
    """Village GIS reference model."""

    __tablename__ = "villages"

    block_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("blocks.id", ondelete="CASCADE"), nullable=False, index=True
    )
    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    geometry: Mapped[WKBElement | None] = mapped_column(
        Geography("MULTIPOLYGON", srid=4326), nullable=True
    )

    block: Mapped["Block"] = relationship("Block", back_populates="villages")
