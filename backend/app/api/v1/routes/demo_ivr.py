"""Demo IVR endpoint to simulate incoming telephony cases."""
import logging
import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.base import get_db
from app.models.animal import Animal
from app.models.audit_log import AuditLog
from app.models.farmer import Farmer
from app.models.health_case import HealthCase
from app.services.event_bus import event_bus
from app.schemas.health_case import HealthCaseOut
from app.api.v1.routes.cases import _to_out, _loc_to_geo
from app.schemas.farmer import LocationIn

logger = logging.getLogger("pashumauli.demo_ivr")
settings = get_settings()

router = APIRouter(prefix="/demo/ivr", tags=["ivr"])

class DemoIVRRequest(BaseModel):
    caller_phone: str
    language: str
    farmer_name: str
    animal_id: str  # treating as ear tag or visual id
    symptoms: str
    latitude: float
    longitude: float


@router.post("/incoming", status_code=status.HTTP_201_CREATED, response_model=HealthCaseOut)
async def simulate_incoming_ivr(
    payload: DemoIVRRequest,
    db: AsyncSession = Depends(get_db),
):
    """Simulate an incoming IVR phone call creating a case.
    
    In a real system, this would be a webhook from Exotel/Twilio,
    guarded by provider authentication.
    """
    if not settings.DEMO_MODE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "FORBIDDEN", "message": "Demo mode is not enabled.", "details": {}}}
        )

    # 1. Lookup or create farmer by phone
    result = await db.execute(select(Farmer).where(Farmer.phone == payload.caller_phone))
    farmer = result.scalar_one_or_none()
    
    if not farmer:
        farmer = Farmer(
            name=payload.farmer_name,
            phone=payload.caller_phone,
            preferred_language=payload.language
        )
        db.add(farmer)
        await db.flush()

    # 2. Lookup or create animal by ear tag
    result = await db.execute(select(Animal).where(Animal.ear_tag_id == payload.animal_id))
    animal = result.scalar_one_or_none()
    
    if not animal:
        animal = Animal(
            farmer_id=farmer.id,
            ear_tag_id=payload.animal_id,
            species="UNKNOWN",  # from IVR we might not know
            breed="UNKNOWN",
        )
        db.add(animal)
        await db.flush()

    # 3. Create case
    case = HealthCase(
        animal_id=animal.id,
        farmer_id=farmer.id,
        source="IVR",
        symptoms=[payload.symptoms],
        location=_loc_to_geo(LocationIn(latitude=payload.latitude, longitude=payload.longitude))
    )
    db.add(case)
    await db.flush()

    # 4. Write audit
    audit = AuditLog(
        actor_user_id=None,  # System/IVR action
        action="IVR_CASE_CREATED",
        entity_type="HEALTH_CASE",
        entity_id=case.id,
        meta={"caller_phone": payload.caller_phone, "language": payload.language}
    )
    db.add(audit)
    
    # 5. Commit and publish events
    await db.commit()
    
    # Publish IVR_RECEIVED (could be useful for a specific UI panel)
    await event_bus.publish(
        event_type="IVR_RECEIVED",
        payload={
            "caller_phone": payload.caller_phone,
            "farmer_name": payload.farmer_name,
            "animal_id": payload.animal_id,
            "symptoms": payload.symptoms,
            "case_id": str(case.id)
        },
        source="IVR"
    )

    # Publish CASE_CREATED for the main dashboard view
    await event_bus.publish(
        event_type="CASE_CREATED",
        payload=_to_out(case).model_dump(mode="json"),
        source="IVR"
    )

    logger.info("demo_ivr_case_created", extra={"case_id": str(case.id), "phone": payload.caller_phone})
    return _to_out(case)
