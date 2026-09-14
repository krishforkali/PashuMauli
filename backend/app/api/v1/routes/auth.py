"""Auth routes: POST /api/v1/auth/register, /login, /refresh."""
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.deps import get_current_user
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.db.base import get_db
from app.models.audit_log import AuditLog
from app.models.user import User, UserRole
from app.schemas.auth import (
    AccessTokenResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserOut,
)
from app.services.event_bus import event_bus

logger = logging.getLogger("pashumauli.auth")
settings = get_settings()

router = APIRouter(prefix="/auth", tags=["auth"])

# Roles whose registration should produce an audit entry
_PRIVILEGED_ROLES = {
    UserRole.DISTRICT_OFFICER,
    UserRole.STATE_ADMIN,
    UserRole.SYSTEM_ADMIN,
}

def _mask_phone(phone: str) -> str:
    """Mask all but last 4 digits: e.g. +91987654xxxx → xxxxxxxx3210."""
    if len(phone) <= 4:
        return "****"
    return "*" * (len(phone) - 4) + phone[-4:]


async def _audit(
    db: AsyncSession,
    action: str,
    actor_id: uuid.UUID | None,
    entity_type: str,
    entity_id: uuid.UUID | None = None,
    metadata: dict | None = None,
) -> None:
    entry = AuditLog(
        actor_user_id=actor_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        meta=metadata or {},
    )
    db.add(entry)
    # Flushed as part of the surrounding session commit (get_db auto-commits)


@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    response_model=UserOut,
)
async def register(
    payload: RegisterRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> UserOut:
    """Create a new user account.

    Role assignment is validated server-side.
    Returns the created user; does *not* issue tokens (client must login).
    """
    # Check phone uniqueness before hashing to give a clean 409
    result = await db.execute(select(User).where(User.phone == payload.phone))
    if result.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "PHONE_TAKEN", "message": "Phone number already registered.", "details": {}}},
        )

    pw_hash = hash_password(payload.password)
    new_user = User(
        name=payload.name,
        phone=payload.phone,
        email=payload.email,
        password_hash=pw_hash,
        role=payload.role.value,
        preferred_language=payload.preferred_language,
    )
    db.add(new_user)
    try:
        await db.flush()  # populate id before audit
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "PHONE_TAKEN", "message": "Phone number already registered.", "details": {}}},
        )

    # Audit privileged role registrations
    if UserRole(new_user.role) in _PRIVILEGED_ROLES:
        await _audit(
            db,
            action="USER_REGISTERED_PRIVILEGED",
            actor_id=None,  # self-registration
            entity_type="user",
            entity_id=new_user.id,
            metadata={"role": new_user.role, "phone_suffix": new_user.phone[-4:]},
        )

    await db.commit()

    logger.info("user_registered", extra={"user_id": str(new_user.id), "role": new_user.role})
    await event_bus.publish(
        event_type="USER_REGISTERED",
        payload=UserOut.model_validate(new_user).model_dump(mode="json"),
        source="SYSTEM"
    )
    return UserOut.model_validate(new_user)


@router.post("/login", response_model=TokenResponse)
async def login(
    payload: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Authenticate with phone + password; return JWT access + refresh tokens."""
    result = await db.execute(select(User).where(User.phone == payload.phone))
    user = result.scalar_one_or_none()

    if user is None or not verify_password(payload.password, user.password_hash):
        await _audit(
            db,
            action="USER_LOGIN_FAILED",
            actor_id=user.id if user else None,
            entity_type="user",
            entity_id=user.id if user else None,
            metadata={"phone": _mask_phone(payload.phone)}
        )
        await db.commit()
        await event_bus.publish(
            event_type="USER_LOGIN_FAILED",
            payload={"phone": _mask_phone(payload.phone)},
            source="SYSTEM"
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "INVALID_CREDENTIALS", "message": "Phone or password incorrect.", "details": {}}},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "ACCOUNT_INACTIVE", "message": "Account is inactive.", "details": {}}},
        )

    access_token = create_access_token(str(user.id), extra={"role": user.role})
    refresh_token = create_refresh_token(str(user.id))

    await _audit(
        db,
        action="USER_LOGIN",
        actor_id=user.id,
        entity_type="user",
        entity_id=user.id,
        metadata={"role": user.role},
    )
    await db.commit()

    logger.info("user_login", extra={"user_id": str(user.id), "role": user.role})
    await event_bus.publish(
        event_type="USER_LOGIN",
        payload={"user_id": str(user.id), "role": user.role},
        actor={"user_id": str(user.id), "role": user.role},
        source="SYSTEM"
    )
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRY,
        user=UserOut.model_validate(user),
    )


@router.post("/refresh", response_model=AccessTokenResponse)
async def refresh(
    payload: RefreshRequest,
    db: AsyncSession = Depends(get_db),
) -> AccessTokenResponse:
    """Issue a new access token from a valid refresh token."""
    from jose import JWTError

    try:
        claims = decode_token(payload.refresh_token)
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "TOKEN_INVALID", "message": str(exc), "details": {}}},
        ) from exc

    if claims.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "TOKEN_INVALID", "message": "Not a refresh token.", "details": {}}},
        )

    user_id_str = claims.get("sub")
    try:
        user_id = uuid.UUID(str(user_id_str))
    except (ValueError, AttributeError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "TOKEN_INVALID", "message": "Invalid sub claim.", "details": {}}},
        ) from exc

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "USER_NOT_FOUND", "message": "User not found or inactive.", "details": {}}},
        )

    new_access = create_access_token(str(user.id), extra={"role": user.role})
    return AccessTokenResponse(
        access_token=new_access,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRY,
    )


@router.get("/me", response_model=UserOut)
async def me(current_user: User = Depends(get_current_user)) -> UserOut:
    """Return the currently authenticated user's profile."""
    return UserOut.model_validate(current_user)
