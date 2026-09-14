"""Farmer routes: POST/GET/PATCH /api/v1/farmers."""
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status
from geoalchemy2.elements import WKBElement
from geoalchemy2.shape import from_shape, to_shape
from shapely.geometry import Point
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, require_roles
from app.db.base import get_db
from app.models.farmer import Farmer
from app.models.user import User, UserRole
from app.schemas.farmer import (
    FarmerCreate,
    FarmerListOut,
    FarmerOut,
    FarmerUpdate,
    LocationIn,
    PaginatedFarmers,
)

logger = logging.getLogger("pashumauli.farmers")

router = APIRouter(prefix="/farmers", tags=["farmers"])

# All authenticated roles may read; writes require FIELD_VET or higher.
_WRITE_ROLES = (
    UserRole.FIELD_VET,
    UserRole.DISTRICT_OFFICER,
    UserRole.STATE_ADMIN,
    UserRole.SYSTEM_ADMIN,
    UserRole.FARMER,  # A FARMER can register themselves
)


def _geography_to_location(geo: WKBElement | None) -> LocationIn | None:
    """Convert PostGIS geography to LocationIn schema."""
    if geo is None:
        return None
    try:
        point = to_shape(geo)
        return LocationIn(longitude=point.x, latitude=point.y)
    except Exception:
        return None


def _location_to_geography(loc: LocationIn | None) -> WKBElement | None:
    """Convert LocationIn schema to PostGIS geography."""
    if loc is None:
        return None
    return from_shape(Point(loc.longitude, loc.latitude), srid=4326)


def _mask_phone(phone: str) -> str:
    """Mask all but last 4 digits: e.g. +91987654xxxx → xxxxxxxx3210."""
    if len(phone) <= 4:
        return "****"
    return "*" * (len(phone) - 4) + phone[-4:]


def _farmer_to_out(farmer: Farmer) -> FarmerOut:
    loc = _geography_to_location(farmer.location)
    return FarmerOut(
        id=farmer.id,
        user_id=farmer.user_id,
        name=farmer.name,
        phone=farmer.phone,
        preferred_language=farmer.preferred_language,
        village_id=farmer.village_id,
        address_text=farmer.address_text,
        location=loc,
        created_at=farmer.created_at,
        updated_at=farmer.updated_at,
    )


def _farmer_to_list_out(farmer: Farmer) -> FarmerListOut:
    return FarmerListOut(
        id=farmer.id,
        name=farmer.name,
        phone_masked=_mask_phone(farmer.phone),
        preferred_language=farmer.preferred_language,
        village_id=farmer.village_id,
        address_text=farmer.address_text,
        created_at=farmer.created_at,
    )


@router.post("", status_code=status.HTTP_201_CREATED, response_model=FarmerOut)
async def create_farmer(
    payload: FarmerCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),  # any authenticated user
) -> FarmerOut:
    """Register a new farmer.

    Emits FARMER_REGISTERED event (stub — Phase 7 WebSocket).
    """
    farmer = Farmer(
        user_id=payload.user_id,
        name=payload.name,
        phone=payload.phone,
        preferred_language=payload.preferred_language,
        village_id=payload.village_id,
        address_text=payload.address_text,
        location=_location_to_geography(payload.location),
    )
    db.add(farmer)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "CONFLICT", "message": "Farmer with that data already exists.", "details": {}}},
        )

    from app.models.audit_log import AuditLog
    from app.services.event_bus import event_bus

    audit_log = AuditLog(
        actor_user_id=current_user.id,
        action="FARMER_CREATED",
        entity_type="FARMER",
        entity_id=farmer.id,
        meta={"phone": _mask_phone(farmer.phone)}
    )
    db.add(audit_log)
    await db.commit()

    logger.info("farmer_registered", extra={"farmer_id": str(farmer.id)})
    await event_bus.publish(
        event_type="FARMER_CREATED",
        payload=_farmer_to_out(farmer).model_dump(mode="json"),
        actor={"user_id": str(current_user.id), "role": current_user.role},
        source="SYSTEM"
    )
    return _farmer_to_out(farmer)


@router.get("", response_model=PaginatedFarmers)
async def list_farmers(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> PaginatedFarmers:
    """List farmers (phone masked). Paginated."""
    offset = (page - 1) * page_size

    count_result = await db.execute(select(func.count()).select_from(Farmer))
    total = count_result.scalar_one()

    result = await db.execute(
        select(Farmer).order_by(Farmer.created_at.desc()).offset(offset).limit(page_size)
    )
    farmers = result.scalars().all()

    return PaginatedFarmers(
        items=[_farmer_to_list_out(f) for f in farmers],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/{farmer_id}", response_model=FarmerOut)
async def get_farmer(
    farmer_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> FarmerOut:
    """Get full farmer detail (full phone visible to authenticated users)."""
    import uuid as _uuid

    try:
        fid = _uuid.UUID(farmer_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "INVALID_ID", "message": "Invalid UUID.", "details": {}}},
        ) from exc

    result = await db.execute(select(Farmer).where(Farmer.id == fid))
    farmer = result.scalar_one_or_none()
    if farmer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Farmer not found.", "details": {}}},
        )
    return _farmer_to_out(farmer)


@router.patch(
    "/{farmer_id}",
    response_model=FarmerOut,
    dependencies=[Depends(require_roles(*_WRITE_ROLES))],
)
async def update_farmer(
    farmer_id: str,
    payload: FarmerUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> FarmerOut:
    """Partial update of a farmer record."""
    import uuid as _uuid

    try:
        fid = _uuid.UUID(farmer_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "INVALID_ID", "message": "Invalid UUID.", "details": {}}},
        ) from exc

    result = await db.execute(select(Farmer).where(Farmer.id == fid))
    farmer = result.scalar_one_or_none()
    if farmer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Farmer not found.", "details": {}}},
        )

    update_data = payload.model_dump(exclude_unset=True)
    if "location" in update_data:
        farmer.location = _location_to_geography(payload.location)
        update_data.pop("location")

    for field, value in update_data.items():
        setattr(farmer, field, value)

    from app.models.audit_log import AuditLog
    from app.services.event_bus import event_bus
    audit_log = AuditLog(
        actor_user_id=current_user.id,
        action="FARMER_UPDATED",
        entity_type="FARMER",
        entity_id=farmer.id,
        meta={"changes": list(update_data.keys())}
    )
    db.add(audit_log)
    await db.commit()

    await event_bus.publish(
        event_type="FARMER_UPDATED",
        payload=_farmer_to_out(farmer).model_dump(mode="json"),
        actor={"user_id": str(current_user.id), "role": current_user.role},
        source="SYSTEM"
    )

    return _farmer_to_out(farmer)
