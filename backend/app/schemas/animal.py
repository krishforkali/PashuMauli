"""Pydantic schemas for animal endpoints."""
import uuid
from datetime import date, datetime

from pydantic import BaseModel, Field

from app.schemas.farmer import LocationIn


class AnimalCreate(BaseModel):
    ear_tag_id: str = Field(..., min_length=1, max_length=64)
    farmer_id: uuid.UUID
    species: str = Field(..., min_length=1, max_length=64)
    breed: str | None = Field(default=None, max_length=128)
    sex: str | None = Field(default=None, max_length=16)
    date_of_birth: date | None = None
    status: str = Field(default="ACTIVE", max_length=32)
    location: LocationIn | None = None


class AnimalUpdate(BaseModel):
    ear_tag_id: str | None = Field(default=None, max_length=64)
    species: str | None = Field(default=None, max_length=64)
    breed: str | None = Field(default=None, max_length=128)
    sex: str | None = Field(default=None, max_length=16)
    date_of_birth: date | None = None
    status: str | None = Field(default=None, max_length=32)
    location: LocationIn | None = None


class AnimalOut(BaseModel):
    id: uuid.UUID
    ear_tag_id: str
    farmer_id: uuid.UUID
    species: str
    breed: str | None
    sex: str | None
    date_of_birth: date | None
    status: str
    location: LocationIn | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class PaginatedAnimals(BaseModel):
    items: list[AnimalOut]
    total: int
    page: int
    page_size: int
