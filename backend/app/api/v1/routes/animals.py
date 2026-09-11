"""Animal routes: POST/GET/PATCH /api/v1/animals."""
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from geoalchemy2.elements import WKBElement
from geoalchemy2.shape import from_shape, to_shape
from shapely.geometry import Point
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, require_roles
from app.db.base import get_db
from app.models.animal import Animal
from app.models.farmer import Farmer
from app.models.user import User, UserRole
from app.schemas.animal import (
    AnimalCreate,
    AnimalOut,
    AnimalUpdate,
    PaginatedAnimals,
)
from app.schemas.farmer import LocationIn

logger = logging.getLogger("pashumauli.animals")

router = APIRouter(prefix="/animals", tags=["animals"])

_WRITE_ROLES = (
    UserRole.FIELD_VET,
    UserRole.DISTRICT_OFFICER,
    UserRole.STATE_ADMIN,
    UserRole.SYSTEM_ADMIN,
    UserRole.FARMER,
)


def _geo_to_loc(geo: WKBElement | None) -> LocationIn | None:
    if geo is None:
        return None
    try:
        pt = to_shape(geo)
        return LocationIn(longitude=pt.x, latitude=pt.y)
    except Exception:
        return None


def _loc_to_geo(loc: LocationIn | None) -> WKBElement | None:
    if loc is None:
        return None
    return from_shape(Point(loc.longitude, loc.latitude), srid=4326)


def _to_out(animal: Animal) -> AnimalOut:
    return AnimalOut(
        id=animal.id,
        ear_tag_id=animal.ear_tag_id,
        farmer_id=animal.farmer_id,
        species=animal.species,
        breed=animal.breed,
        sex=animal.sex,
        date_of_birth=animal.date_of_birth,
        status=animal.status,
        location=_geo_to_loc(animal.location),
        created_at=animal.created_at,
        updated_at=animal.updated_at,
    )


@router.post("", status_code=status.HTTP_201_CREATED, response_model=AnimalOut)
async def create_animal(
    payload: AnimalCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> AnimalOut:
    """Register a new animal. ear_tag_id must be unique (409 if duplicate)."""
    # Verify farmer exists
    farmer_result = await db.execute(
        select(Farmer).where(Farmer.id == payload.farmer_id)
    )
    if farmer_result.scalar_one_or_none() is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "FARMER_NOT_FOUND", "message": "Farmer not found.", "details": {}}},
        )

    animal = Animal(
        ear_tag_id=payload.ear_tag_id,
        farmer_id=payload.farmer_id,
        species=payload.species,
        breed=payload.breed,
        sex=payload.sex,
        date_of_birth=payload.date_of_birth,
        status=payload.status,
        location=_loc_to_geo(payload.location),
    )
    db.add(animal)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "EAR_TAG_TAKEN", "message": "ear_tag_id already exists.", "details": {}}},
        )

    # Phase 7 stub: ANIMAL_REGISTERED WebSocket event would be emitted here.
    logger.info("animal_registered", extra={"animal_id": str(animal.id)})
    return _to_out(animal)


@router.get("", response_model=PaginatedAnimals)
async def list_animals(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    farmer_id: uuid.UUID | None = Query(default=None),
    species: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> PaginatedAnimals:
    """List animals with optional filters."""
    q = select(Animal)
    if farmer_id is not None:
        q = q.where(Animal.farmer_id == farmer_id)
    if species is not None:
        q = q.where(Animal.species == species)
    if status_filter is not None:
        q = q.where(Animal.status == status_filter)

    count_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = count_result.scalar_one()

    offset = (page - 1) * page_size
    result = await db.execute(
        q.order_by(Animal.created_at.desc()).offset(offset).limit(page_size)
    )
    animals = result.scalars().all()

    return PaginatedAnimals(
        items=[_to_out(a) for a in animals],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/{animal_id}", response_model=AnimalOut)
async def get_animal(
    animal_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> AnimalOut:
    """Get single animal detail."""
    try:
        aid = uuid.UUID(animal_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "INVALID_ID", "message": "Invalid UUID.", "details": {}}},
        ) from exc

    result = await db.execute(select(Animal).where(Animal.id == aid))
    animal = result.scalar_one_or_none()
    if animal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Animal not found.", "details": {}}},
        )
    return _to_out(animal)


@router.patch(
    "/{animal_id}",
    response_model=AnimalOut,
    dependencies=[Depends(require_roles(*_WRITE_ROLES))],
)
async def update_animal(
    animal_id: str,
    payload: AnimalUpdate,
    db: AsyncSession = Depends(get_db),
) -> AnimalOut:
    """Partial update of an animal record."""
    try:
        aid = uuid.UUID(animal_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "INVALID_ID", "message": "Invalid UUID.", "details": {}}},
        ) from exc

    result = await db.execute(select(Animal).where(Animal.id == aid))
    animal = result.scalar_one_or_none()
    if animal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Animal not found.", "details": {}}},
        )

    update_data = payload.model_dump(exclude_unset=True)
    if "location" in update_data:
        animal.location = _loc_to_geo(payload.location)
        update_data.pop("location")

    try:
        for field, value in update_data.items():
            setattr(animal, field, value)
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "EAR_TAG_TAKEN", "message": "ear_tag_id already exists.", "details": {}}},
        )

    return _to_out(animal)
