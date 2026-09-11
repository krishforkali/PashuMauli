"""Pydantic schemas for authentication endpoints."""
import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.models.user import UserRole

# ---------------------------------------------------------------------------
# Request bodies
# ---------------------------------------------------------------------------

class RegisterRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    phone: str = Field(..., min_length=7, max_length=32)
    password: str = Field(..., min_length=8, max_length=128)
    role: UserRole = UserRole.FARMER
    email: str | None = Field(default=None, max_length=255)
    preferred_language: str = Field(default="en", max_length=16)

    @field_validator("phone")
    @classmethod
    def phone_digits(cls, v: str) -> str:
        stripped = v.strip().replace("+", "").replace("-", "").replace(" ", "")
        if not stripped.isdigit():
            raise ValueError("Phone must contain only digits (and optional leading +/-/spaces).")
        return v.strip()


class LoginRequest(BaseModel):
    phone: str = Field(..., min_length=7, max_length=32)
    password: str = Field(..., min_length=1, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str


# ---------------------------------------------------------------------------
# Response bodies
# ---------------------------------------------------------------------------

class UserOut(BaseModel):
    id: uuid.UUID
    name: str
    phone: str
    email: str | None
    role: str
    preferred_language: str
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int
    user: UserOut


class AccessTokenResponse(BaseModel):
    access_token: str
    token_type: str = "Bearer"
    expires_in: int
