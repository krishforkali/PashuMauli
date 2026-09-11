"""Pydantic schemas for health case endpoints."""
import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from app.schemas.farmer import LocationIn

# Allowed sources per DATABASE_SCHEMA.md
VALID_SOURCES = {"MOBILE", "IVR", "DASHBOARD", "IMPORT"}

# Allowed risk levels
VALID_RISK_LEVELS = {"UNKNOWN", "LOW", "MEDIUM", "HIGH", "CRITICAL"}

# Allowed case statuses
VALID_STATUSES = {"OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"}


class HealthCaseCreate(BaseModel):
    client_id: uuid.UUID | None = None  # for offline idempotency
    animal_id: uuid.UUID | None = None
    farmer_id: uuid.UUID | None = None
    source: str = Field(default="DASHBOARD", max_length=32)
    symptoms: list[Any] = Field(default_factory=list)
    suspected_disease: str | None = Field(default=None, max_length=128)
    location: LocationIn | None = None


class HealthCasePatch(BaseModel):
    status: str | None = Field(default=None, max_length=32)
    suspected_disease: str | None = Field(default=None, max_length=128)
    risk_level: str | None = Field(default=None, max_length=32)
    symptoms: list[Any] | None = None
    location: LocationIn | None = None


class AIResultCreate(BaseModel):
    model_config = {"protected_namespaces": ()}

    model_name: str = Field(..., max_length=128)
    model_version: str = Field(..., max_length=64)
    input_type: str = Field(..., max_length=64)
    predictions: dict[str, Any] = Field(default_factory=dict)
    top_prediction: str | None = Field(default=None, max_length=128)
    confidence: float | None = Field(default=None, ge=0.0, le=1.0)
    inference_ms: float | None = None


class AIResultOut(BaseModel):
    model_config = {"from_attributes": True, "protected_namespaces": ()}

    id: uuid.UUID
    case_id: uuid.UUID
    model_name: str
    model_version: str
    input_type: str
    predictions: dict[str, Any]
    top_prediction: str | None
    confidence: float | None
    inference_ms: float | None
    created_at: datetime


class HealthCaseOut(BaseModel):
    id: uuid.UUID
    client_id: uuid.UUID | None
    animal_id: uuid.UUID | None
    farmer_id: uuid.UUID | None
    reported_by: uuid.UUID | None
    source: str
    symptoms: list[Any]
    suspected_disease: str | None
    confidence: float | None
    risk_score: float | None
    risk_level: str
    status: str
    location: LocationIn | None
    ai_model_version: str | None
    advisory_version: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class PaginatedCases(BaseModel):
    items: list[HealthCaseOut]
    total: int
    page: int
    page_size: int
