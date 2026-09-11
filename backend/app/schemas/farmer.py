"""Pydantic schemas for farmer endpoints."""
import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class LocationIn(BaseModel):
    """GeoJSON Point coordinates input."""

    longitude: float = Field(..., ge=-180, le=180)
    latitude: float = Field(..., ge=-90, le=90)


class FarmerCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    phone: str = Field(..., min_length=7, max_length=32)
    preferred_language: str = Field(default="mr", max_length=16)
    village_id: uuid.UUID | None = None
    address_text: str | None = None
    location: LocationIn | None = None
    user_id: uuid.UUID | None = None  # optional link to a user account


class FarmerUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=32)
    preferred_language: str | None = Field(default=None, max_length=16)
    village_id: uuid.UUID | None = None
    address_text: str | None = None
    location: LocationIn | None = None


class FarmerOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID | None
    name: str
    # Phone is partially masked in list responses per SECURITY.md privacy rule.
    # Full phone returned in detail response only.
    phone: str
    preferred_language: str
    village_id: uuid.UUID | None
    address_text: str | None
    location: LocationIn | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class FarmerListOut(BaseModel):
    """Masked-phone version for list responses."""

    id: uuid.UUID
    name: str
    phone_masked: str
    preferred_language: str
    village_id: uuid.UUID | None
    address_text: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class PaginatedFarmers(BaseModel):
    items: list[FarmerListOut]
    total: int
    page: int
    page_size: int
