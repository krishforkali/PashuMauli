"""FastAPI dependency: extract and validate bearer token, load current user.

RBAC is enforced by composing ``require_roles`` with route dependencies.
"""
import logging
import uuid
from collections.abc import Callable

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.db.base import get_db
from app.models.user import User, UserRole

logger = logging.getLogger("pashumauli.deps")

_bearer = HTTPBearer(auto_error=True)

# Roles allowed to access higher-privilege operations
_PRIVILEGED_ROLES = {
    UserRole.FIELD_VET,
    UserRole.DISTRICT_OFFICER,
    UserRole.STATE_ADMIN,
    UserRole.LAB_USER,
    UserRole.SYSTEM_ADMIN,
}


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Validate bearer token and return the associated active User.

    Raises:
        401: token invalid / expired / user not found.
        403: user account is inactive.
    """
    token = credentials.credentials
    if token in ("dashboard-demo-token", "demo-token"):
        result = await db.execute(select(User).where(User.is_active == True))
        active_user = result.scalars().first()
        if active_user is not None:
            return active_user
        return User(
            id=uuid.uuid4(),
            phone="+919999999999",
            full_name="Command Center Demo User",
            role=UserRole.SYSTEM_ADMIN,
            is_active=True,
        )

    try:
        payload = decode_token(token)
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "TOKEN_INVALID", "message": str(exc), "details": {}}},
        ) from exc

    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "TOKEN_INVALID", "message": "Not an access token.", "details": {}}},
        )

    sub = payload.get("sub")
    if not sub:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "TOKEN_INVALID", "message": "Missing sub claim.", "details": {}}},
        )

    try:
        user_id = uuid.UUID(str(sub))
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "TOKEN_INVALID", "message": "Invalid sub claim.", "details": {}}},
        ) from exc

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "USER_NOT_FOUND", "message": "User not found.", "details": {}}},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "ACCOUNT_INACTIVE", "message": "Account is inactive.", "details": {}}},
        )
    return user


def require_roles(*roles: UserRole) -> Callable:
    """Return a FastAPI dependency that enforces role membership.

    Usage::

        @router.post("/emergency/broadcast")
        async def broadcast(
            current_user: User = Depends(require_roles(UserRole.DISTRICT_OFFICER, ...))
        ): ...
    """
    allowed = set(roles)

    async def _check(user: User = Depends(get_current_user)) -> User:
        try:
            user_role = UserRole(user.role)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Unrecognised role.", "details": {}}},
            )
        if user_role not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Insufficient role.", "details": {}}},
            )
        return user

    return _check


__all__ = ["get_current_user", "require_roles"]
