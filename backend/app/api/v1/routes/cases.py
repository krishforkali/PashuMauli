"""Health case routes: POST/GET/PATCH /api/v1/cases + AI result stub."""
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from geoalchemy2.shape import from_shape, to_shape
from shapely.geometry import Point
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.base import get_db
from app.models.health_case import AIResult, HealthCase
from app.models.user import User
from app.schemas.farmer import LocationIn
from app.schemas.health_case import (
    VALID_SOURCES,
    VALID_STATUSES,
    AIResultCreate,
    AIResultOut,
    HealthCaseCreate,
    HealthCaseOut,
    HealthCasePatch,
    PaginatedCases,
)

logger = logging.getLogger("pashumauli.cases")

router = APIRouter(prefix="/cases", tags=["cases"])


def _geo_to_loc(geo) -> LocationIn | None:
    if geo is None:
        return None
    try:
        pt = to_shape(geo)
        return LocationIn(longitude=pt.x, latitude=pt.y)
    except Exception:
        return None


def _loc_to_geo(loc: LocationIn | None):
    if loc is None:
        return None
    return from_shape(Point(loc.longitude, loc.latitude), srid=4326)


def _to_out(case: HealthCase) -> HealthCaseOut:
    return HealthCaseOut(
        id=case.id,
        client_id=case.client_id,
        animal_id=case.animal_id,
        farmer_id=case.farmer_id,
        reported_by=case.reported_by,
        source=case.source,
        symptoms=case.symptoms if isinstance(case.symptoms, list) else [],
        suspected_disease=case.suspected_disease,
        confidence=case.confidence,
        risk_score=case.risk_score,
        risk_level=case.risk_level,
        status=case.status,
        location=_geo_to_loc(case.location),
        ai_model_version=case.ai_model_version,
        advisory_version=case.advisory_version,
        created_at=case.created_at,
        updated_at=case.updated_at,
    )


@router.post("", status_code=status.HTTP_201_CREATED, response_model=HealthCaseOut)
async def create_case(
    payload: HealthCaseCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> HealthCaseOut:
    """Create a health case.

    If ``client_id`` is provided and already exists, the existing record is
    returned with HTTP 200 (idempotent offline sync — ALREADY_APPLIED).
    """
    if payload.source not in VALID_SOURCES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "INVALID_SOURCE", "message": f"source must be one of {sorted(VALID_SOURCES)}", "details": {}}},
        )

    # Idempotency: client_id deduplication
    if payload.client_id is not None:
        existing = await db.execute(
            select(HealthCase).where(HealthCase.client_id == payload.client_id)
        )
        existing_case = existing.scalar_one_or_none()
        if existing_case is not None:
            logger.info(
                "case_already_applied",
                extra={"client_id": str(payload.client_id), "case_id": str(existing_case.id)},
            )
            # Return 200 with existing record — ALREADY_APPLIED
            from fastapi.responses import JSONResponse
            return JSONResponse(
                status_code=status.HTTP_200_OK,
                content=_to_out(existing_case).model_dump(mode="json"),
            )

    case = HealthCase(
        client_id=payload.client_id,
        animal_id=payload.animal_id,
        farmer_id=payload.farmer_id,
        reported_by=current_user.id,
        source=payload.source,
        symptoms=payload.symptoms,
        suspected_disease=payload.suspected_disease,
        location=_loc_to_geo(payload.location),
    )
    db.add(case)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        # Race condition: client_id inserted by concurrent request
        existing = await db.execute(
            select(HealthCase).where(HealthCase.client_id == payload.client_id)
        )
        existing_case = existing.scalar_one_or_none()
        if existing_case is not None:
            from fastapi.responses import JSONResponse
            return JSONResponse(
                status_code=status.HTTP_200_OK,
                content=_to_out(existing_case).model_dump(mode="json"),
            )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "CONFLICT", "message": "Conflict on case creation.", "details": {}}},
        )

    # Phase 7 stub: HEALTH_CASE_CREATED WebSocket event would be emitted here.
    logger.info("health_case_created", extra={"case_id": str(case.id), "source": case.source})
    return _to_out(case)


@router.get("", response_model=PaginatedCases)
async def list_cases(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    status_filter: str | None = Query(default=None, alias="status"),
    risk_level: str | None = Query(default=None),
    source: str | None = Query(default=None),
    suspected_disease: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> PaginatedCases:
    """List health cases with optional filters."""
    q = select(HealthCase)
    if status_filter is not None:
        q = q.where(HealthCase.status == status_filter)
    if risk_level is not None:
        q = q.where(HealthCase.risk_level == risk_level)
    if source is not None:
        q = q.where(HealthCase.source == source)
    if suspected_disease is not None:
        q = q.where(HealthCase.suspected_disease == suspected_disease)

    count_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = count_result.scalar_one()

    offset = (page - 1) * page_size
    result = await db.execute(
        q.order_by(HealthCase.created_at.desc()).offset(offset).limit(page_size)
    )
    cases = result.scalars().all()

    return PaginatedCases(
        items=[_to_out(c) for c in cases],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/{case_id}", response_model=HealthCaseOut)
async def get_case(
    case_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> HealthCaseOut:
    """Get single health case."""
    try:
        cid = uuid.UUID(case_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "INVALID_ID", "message": "Invalid UUID.", "details": {}}},
        ) from exc

    result = await db.execute(select(HealthCase).where(HealthCase.id == cid))
    case = result.scalar_one_or_none()
    if case is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Health case not found.", "details": {}}},
        )
    return _to_out(case)


@router.patch("/{case_id}", response_model=HealthCaseOut)
async def patch_case(
    case_id: str,
    payload: HealthCasePatch,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> HealthCaseOut:
    """Partial update of a health case (status, disease, risk_level, etc.)."""
    try:
        cid = uuid.UUID(case_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "INVALID_ID", "message": "Invalid UUID.", "details": {}}},
        ) from exc

    result = await db.execute(select(HealthCase).where(HealthCase.id == cid))
    case = result.scalar_one_or_none()
    if case is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Health case not found.", "details": {}}},
        )

    if payload.status is not None and payload.status not in VALID_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "INVALID_STATUS", "message": f"status must be one of {sorted(VALID_STATUSES)}", "details": {}}},
        )

    update_data = payload.model_dump(exclude_unset=True)
    if "location" in update_data:
        case.location = _loc_to_geo(payload.location)
        update_data.pop("location")

    for field, value in update_data.items():
        setattr(case, field, value)

    await db.flush()
    return _to_out(case)


@router.post("/{case_id}/ai-result", status_code=status.HTTP_201_CREATED, response_model=AIResultOut)
async def attach_ai_result(
    case_id: str,
    payload: AIResultCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> AIResultOut:
    """Attach an AI inference result to a health case (stub; full logic in Phase 5).

    Stores the result in ai_results and updates case.ai_model_version.
    Risk engine integration is a Phase 5 responsibility.
    """
    try:
        cid = uuid.UUID(case_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "INVALID_ID", "message": "Invalid UUID.", "details": {}}},
        ) from exc

    result = await db.execute(select(HealthCase).where(HealthCase.id == cid))
    case = result.scalar_one_or_none()
    if case is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Health case not found.", "details": {}}},
        )

    ai_result = AIResult(
        case_id=cid,
        model_name=payload.model_name,
        model_version=payload.model_version,
        input_type=payload.input_type,
        predictions=payload.predictions,
        top_prediction=payload.top_prediction,
        confidence=payload.confidence,
        inference_ms=payload.inference_ms,
    )
    db.add(ai_result)

    # Update case with model version and top prediction
    case.ai_model_version = payload.model_version
    if payload.top_prediction is not None:
        case.suspected_disease = payload.top_prediction
    if payload.confidence is not None:
        case.confidence = payload.confidence

    await db.flush()

    # Phase 5 stub: risk engine call and AI_RESULT_AVAILABLE WS event go here.
    logger.info(
        "ai_result_attached",
        extra={"case_id": case_id, "model": payload.model_name, "version": payload.model_version},
    )

    return AIResultOut(
        id=ai_result.id,
        case_id=ai_result.case_id,
        model_name=ai_result.model_name,
        model_version=ai_result.model_version,
        input_type=ai_result.input_type,
        predictions=ai_result.predictions,
        top_prediction=ai_result.top_prediction,
        confidence=ai_result.confidence,
        inference_ms=ai_result.inference_ms,
        created_at=ai_result.created_at,
    )
