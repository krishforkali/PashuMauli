"""Demo IVR endpoints for interactive Gather -> Passthru telephony simulation."""
import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.routes.cases import _loc_to_geo, _to_out
from app.core.config import get_settings
from app.db.base import get_db
from app.models.animal import Animal
from app.models.audit_log import AuditLog
from app.models.farmer import Farmer
from app.models.health_case import HealthCase
from app.schemas.farmer import LocationIn
from app.schemas.health_case import HealthCaseOut
from app.services.event_bus import event_bus
from app.services.telephony import IVRStep, telephony_provider

logger = logging.getLogger("pashumauli.demo_ivr")
settings = get_settings()

router = APIRouter(prefix="/demo/ivr", tags=["ivr"])


class DemoIVRStartRequest(BaseModel):
    caller_phone: str = "+919999999999"
    language: str = "mr"


class DemoIVRPassthruRequest(BaseModel):
    call_id: str
    digits: str


class DemoIVRRequest(BaseModel):
    caller_phone: str
    language: str
    farmer_name: str
    animal_id: str  # ear tag or visual id
    symptoms: str
    latitude: float
    longitude: float


class DemoIVRPassthruResponse(BaseModel):
    call_id: str
    current_step: str
    prompt: str
    is_valid: bool = True
    case_created: bool = False
    case: HealthCaseOut | None = None


async def _create_ivr_case(
    db: AsyncSession,
    caller_phone: str,
    farmer_name: str,
    animal_ear_tag: str,
    symptoms_list: list[str],
    language: str,
    latitude: float = 18.5204,
    longitude: float = 73.8567,
) -> HealthCase:
    """Helper to create a real HealthCase, AuditLog, and publish events for IVR calls."""
    # 1. Lookup or create farmer by phone
    farmer_query = await db.execute(select(Farmer).where(Farmer.phone == caller_phone))
    farmer: Farmer | None = farmer_query.scalars().first()

    if farmer is None:
        farmer = Farmer(
            name=farmer_name,
            phone=caller_phone,
            preferred_language=language,
        )
        db.add(farmer)
        await db.flush()

    # 2. Lookup or create animal by ear tag
    animal_query = await db.execute(select(Animal).where(Animal.ear_tag_id == animal_ear_tag))
    animal: Animal | None = animal_query.scalars().first()

    if animal is None:
        animal = Animal(
            farmer_id=farmer.id,
            ear_tag_id=animal_ear_tag,
            species="CATTLE",  # Default for IVR
            breed="LOCAL",
        )
        db.add(animal)
        await db.flush()

    # 3. Create case
    case = HealthCase(
        animal_id=animal.id,
        farmer_id=farmer.id,
        source="IVR",
        symptoms=symptoms_list if symptoms_list else ["UNSPECIFIED_IVR_SYMPTOM"],
        location=_loc_to_geo(LocationIn(latitude=latitude, longitude=longitude)),
        risk_level="HIGH" if len(symptoms_list) >= 2 else "MEDIUM",
        status="OPEN",
    )
    db.add(case)
    await db.flush()

    # 4. Write audit
    audit = AuditLog(
        actor_user_id=None,  # System/IVR action
        action="IVR_CASE_CREATED",
        entity_type="HEALTH_CASE",
        entity_id=case.id,
        meta={"caller_phone": caller_phone, "language": language, "symptoms_count": len(symptoms_list)},
    )
    db.add(audit)

    # 5. Commit & publish events
    await db.commit()

    # Publish IVR_RECEIVED event
    await event_bus.publish(
        event_type="IVR_RECEIVED",
        payload={
            "caller_phone": caller_phone,
            "farmer_name": farmer.name,
            "animal_id": animal.ear_tag_id,
            "symptoms": ", ".join(symptoms_list),
            "case_id": str(case.id),
        },
        source="IVR",
    )

    # Publish CASE_CREATED event for Dashboard live map & feed
    await event_bus.publish(
        event_type="CASE_CREATED",
        payload=_to_out(case).model_dump(mode="json"),
        source="IVR",
    )

    logger.info("demo_ivr_case_created", extra={"case_id": str(case.id), "phone": caller_phone})
    return case


@router.post("/call/start", status_code=status.HTTP_200_OK, response_model=DemoIVRPassthruResponse)
async def start_ivr_call(payload: DemoIVRStartRequest) -> dict[str, Any]:
    """Start a new interactive IVR call session (returns WELCOME Gather prompt)."""
    if not settings.DEMO_MODE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "FORBIDDEN", "message": "Demo mode is not enabled.", "details": {}}},
        )

    session = telephony_provider.start_call(caller_phone=payload.caller_phone, language=payload.language)
    return {
        "call_id": session.call_id,
        "current_step": session.current_step.value,
        "prompt": session.get_prompt_text(),
        "is_valid": True,
        "case_created": False,
        "case": None,
    }


@router.post("/call/step", status_code=status.HTTP_200_OK, response_model=DemoIVRPassthruResponse)
async def process_ivr_passthru_step(
    payload: DemoIVRPassthruRequest,
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Synchronous Passthru webhook (Make Passthru Async = OFF).

    Receives DTMF digits, advances the IVR session state machine, and creates a
    real HealthCase upon confirmation.
    """
    if not settings.DEMO_MODE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "FORBIDDEN", "message": "Demo mode is not enabled.", "details": {}}},
        )

    try:
        session, is_valid, prompt_text = telephony_provider.process_passthru_digit(
            call_id=payload.call_id, digits=payload.digits
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "SESSION_NOT_FOUND", "message": str(exc), "details": {}}},
        ) from exc

    case_created = False
    case_out = None

    # If session reached CONFIRMATION step, finalize the real HealthCase
    if session.current_step == IVRStep.CONFIRMATION:
        case = await _create_ivr_case(
            db=db,
            caller_phone=session.caller_phone,
            farmer_name=session.farmer_name,
            animal_ear_tag=session.animal_ear_tag,
            symptoms_list=session.collected_symptoms,
            language=session.language,
            latitude=session.latitude,
            longitude=session.longitude,
        )
        case_created = True
        case_out = _to_out(case)
        session.current_step = IVRStep.COMPLETED

    return {
        "call_id": session.call_id,
        "current_step": session.current_step.value,
        "prompt": prompt_text,
        "is_valid": is_valid,
        "case_created": case_created,
        "case": case_out,
    }


@router.post("/incoming", status_code=status.HTTP_201_CREATED, response_model=HealthCaseOut)
async def simulate_incoming_ivr(
    payload: DemoIVRRequest,
    db: AsyncSession = Depends(get_db),
) -> HealthCaseOut:
    """Instant single-request simulation of an incoming IVR phone call creating a case."""
    if not settings.DEMO_MODE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "FORBIDDEN", "message": "Demo mode is not enabled.", "details": {}}},
        )

    case = await _create_ivr_case(
        db=db,
        caller_phone=payload.caller_phone,
        farmer_name=payload.farmer_name,
        animal_ear_tag=payload.animal_id,
        symptoms_list=[payload.symptoms],
        language=payload.language,
        latitude=payload.latitude,
        longitude=payload.longitude,
    )
    return _to_out(case)
