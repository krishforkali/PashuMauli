"""Security utilities: password hashing (bcrypt) and JWT encode/decode.

Secrets are read exclusively from environment; never hardcoded.
"""
import logging
from datetime import UTC, datetime, timedelta
from typing import Any, cast

import bcrypt
from jose import JWTError, jwt

from app.core.config import get_settings

logger = logging.getLogger("pashumauli.security")

settings = get_settings()


# ---------------------------------------------------------------------------
# Password hashing
# ---------------------------------------------------------------------------

def hash_password(plain: str) -> str:
    """Return a bcrypt hash of *plain*."""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(plain.encode(), salt).decode()


def verify_password(plain: str, hashed: str) -> bool:
    """Return True if *plain* matches *hashed*."""
    return bcrypt.checkpw(plain.encode(), hashed.encode())


# ---------------------------------------------------------------------------
# JWT
# ---------------------------------------------------------------------------

def _now_utc() -> datetime:
    return datetime.now(UTC)


def create_access_token(subject: str, extra: dict[str, Any] | None = None) -> str:
    """Create a signed JWT access token.

    Args:
        subject: The ``sub`` claim value (typically the user UUID string).
        extra:   Additional claims to include (e.g., role).

    Returns:
        Encoded JWT string.
    """
    payload: dict[str, Any] = {
        "sub": subject,
        "iat": _now_utc(),
        "exp": _now_utc() + timedelta(seconds=settings.JWT_ACCESS_TOKEN_EXPIRY),
        "type": "access",
    }
    if extra:
        payload.update(extra)
    return cast(str, jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM))


def create_refresh_token(subject: str) -> str:
    """Create a signed JWT refresh token."""
    payload: dict[str, Any] = {
        "sub": subject,
        "iat": _now_utc(),
        "exp": _now_utc() + timedelta(seconds=settings.JWT_REFRESH_TOKEN_EXPIRY),
        "type": "refresh",
    }
    return cast(str, jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM))


def decode_token(token: str) -> dict[str, Any]:
    """Decode and validate a JWT.

    Raises:
        JWTError: If signature invalid, expired, or malformed.
    """
    return cast(
        dict[str, Any],
        jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
        ),
    )


def decode_token_unchecked(token: str) -> dict[str, Any] | None:
    """Decode without raising; returns None on any error."""
    try:
        return decode_token(token)
    except JWTError:
        return None


__all__ = [
    "hash_password",
    "verify_password",
    "create_access_token",
    "create_refresh_token",
    "decode_token",
    "decode_token_unchecked",
]
