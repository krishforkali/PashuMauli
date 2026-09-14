"""Exotel Webhook Adapter for PashuMauli IVR (GET /api/v1/ivr/exotel/passthru)."""
import logging
import uuid
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
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
from app.services.event_bus import event_bus
from app.services.telephony import ExotelSessionStore, normalize_exotel_digits

logger = logging.getLogger("pashumauli.exotel_ivr")
settings = get_settings()

router = APIRouter(prefix="/ivr/exotel", tags=["exotel-ivr"])

VALID_STAGES = (
    "language",
    "farmer_id",
    "animal_id",
    "symptom_1",
    "symptom_2",
    "symptom_3",
    "symptom_4",
    "symptom_5",
    "confirmation",
)

# 5 Exact Approved Symptoms for PashuMauli
SYMPTOM_STAGE_MAP = {
    "symptom_1": "eating_problem",
    "symptom_2": "fever",
    "symptom_3": "respiratory_problem",
    "symptom_4": "digestive_problem",
    "symptom_5": "movement_or_visible_abnormality",
}

NEXT_STAGE_MAP = {
    "symptom_1": "symptom_2",
    "symptom_2": "symptom_3",
    "symptom_3": "symptom_4",
    "symptom_4": "symptom_5",
    "symptom_5": "confirmation",
}


@router.get("/passthru", status_code=status.HTTP_200_OK)
async def exotel_passthru_webhook(
    stage: str = Query(default="", alias="stage"),
    CallSid: str = Query(default="", alias="CallSid"),
    CallFrom: str | None = Query(default=None, alias="CallFrom"),
    From: str | None = Query(default=None, alias="From"),
    To: str | None = Query(default=None, alias="To"),
    digits: Any = Query(default=None, alias="digits"),
    CurrentTime: str | None = Query(default=None, alias="CurrentTime"),
    secret: str | None = Query(default=None, alias="secret"),
    x_exotel_secret: str | None = Header(default=None, alias="X-Exotel-Secret"),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """Exotel Synchronous Passthru Webhook (Make Passthru Async = OFF).

    Receives Exotel query parameters, validates DTMF input for the specified stage,
    stores call state in Redis (pashumauli:ivr:session:{CallSid}), and creates a real HealthCase
    upon confirmation.
    """
    if not settings.EXOTEL_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "EXOTEL_DISABLED", "message": "Exotel IVR is disabled.", "details": {}}},
        )

    # Security shared secret validation
    if settings.EXOTEL_WEBHOOK_SHARED_SECRET:
        provided_secret = secret or x_exotel_secret
        if provided_secret != settings.EXOTEL_WEBHOOK_SHARED_SECRET:
            logger.warning("exotel_security_validation_failed", extra={"call_sid": CallSid})
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "INVALID_SECRET", "message": "Invalid webhook secret.", "details": {}}},
            )
    else:
        logger.debug("exotel_security_notice: EXOTEL_WEBHOOK_SHARED_SECRET is not set.")

    # 1. Validate mandatory CallSid & stage
    call_sid = CallSid.strip()
    if not call_sid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "MISSING_CALLSID", "message": "CallSid parameter is required.", "details": {}}},
        )

    stage_norm = stage.strip().lower()
    if stage_norm not in VALID_STAGES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": {
                    "code": "UNKNOWN_STAGE",
                    "message": f"Invalid stage '{stage}'. Must be one of {list(VALID_STAGES)}.",
                    "details": {},
                }
            },
        )

    caller_number = (CallFrom or From or "+919999999999").strip()
    clean_digits = normalize_exotel_digits(digits)
    redis = event_bus.redis

    session = await ExotelSessionStore.get_session(redis, call_sid)
    if not session:
        session = {
            "call_sid": call_sid,
            "caller_number": caller_number,
            "current_stage": stage_norm,
            "language": "mr",
            "farmer_id": None,
            "animal_id": None,
            "symptoms": {
                "eating_problem": False,
                "fever": False,
                "respiratory_problem": False,
                "digestive_problem": False,
                "movement_or_visible_abnormality": False,
            },
            "confirmation": None,
            "case_id": None,
        }
        logger.info("ivr_call_started", extra={"call_sid": call_sid, "caller": caller_number})
        # Publish IVR_RECEIVED event on call initialization
        await event_bus.publish(
            event_type="IVR_RECEIVED",
            payload={
                "call_sid": call_sid,
                "caller_number": caller_number,
                "stage": stage_norm,
            },
            source="IVR",
        )

    # 3. Stage Machine Logic
    # -------------------------------------------------------------------------
    # Stage A: LANGUAGE
    # -------------------------------------------------------------------------
    if stage_norm == "language":
        if clean_digits == "1":
            lang = "hi"
        elif clean_digits == "2":
            lang = "mr"
        elif clean_digits == "3":
            lang = "en"
        else:
            logger.warning("ivr_invalid_language_digits", extra={"call_sid": call_sid, "digits": clean_digits})
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": {"code": "INVALID_INPUT", "message": "Language must be 1 (hi), 2 (mr), or 3 (en).", "details": {}}},
            )

        session["language"] = lang
        session["current_stage"] = "farmer_id"
        await ExotelSessionStore.save_session(redis, session)
        logger.info("ivr_language_selected", extra={"call_sid": call_sid, "language": lang})
        return {"status": "success", "stage": "language", "language": lang}

    # -------------------------------------------------------------------------
    # Stage B: FARMER_ID
    # -------------------------------------------------------------------------
    if stage_norm == "farmer_id":
        if not clean_digits:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": {"code": "INVALID_INPUT", "message": "Farmer ID/Phone digits required.", "details": {}}},
            )

        # Look up existing farmer by phone or ID. DO NOT auto-create farmer for real Exotel flow.
        farmer_query = await db.execute(
            select(Farmer).where(
                (Farmer.phone == clean_digits)
                | (Farmer.phone.endswith(clean_digits))
            )
        )
        farmer: Farmer | None = farmer_query.scalars().first()

        if farmer is None:
            # Check if digits is a valid UUID
            try:
                farmer_uuid = uuid.UUID(clean_digits)
                farmer_query_uuid = await db.execute(select(Farmer).where(Farmer.id == farmer_uuid))
                farmer = farmer_query_uuid.scalars().first()
            except ValueError:
                farmer = None

        if farmer is None:
            logger.warning("ivr_farmer_not_found", extra={"call_sid": call_sid, "digits": clean_digits})
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": {"code": "FARMER_NOT_FOUND", "message": "Farmer record not found for digits.", "details": {}}},
            )

        session["farmer_id"] = str(farmer.id)
        session["current_stage"] = "animal_id"
        await ExotelSessionStore.save_session(redis, session)
        logger.info("ivr_farmer_identified", extra={"call_sid": call_sid, "farmer_id": str(farmer.id)})
        return {"status": "success", "stage": "farmer_id", "farmer_id": str(farmer.id)}

    # -------------------------------------------------------------------------
    # Stage C: ANIMAL_ID (with CRITICAL ownership validation)
    # -------------------------------------------------------------------------
    if stage_norm == "animal_id":
        if not clean_digits:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": {"code": "INVALID_INPUT", "message": "Animal Ear Tag digits required.", "details": {}}},
            )

        farmer_id_str = session.get("farmer_id")
        if not farmer_id_str:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": {"code": "FARMER_NOT_SET", "message": "Farmer ID must be set before animal ID.", "details": {}}},
            )

        # Look up existing animal by ear tag ID
        animal_query = await db.execute(
            select(Animal).where(
                (Animal.ear_tag_id == clean_digits)
                | (Animal.ear_tag_id == f"TAG-{clean_digits}")
            )
        )
        animal: Animal | None = animal_query.scalars().first()

        if animal is None:
            # Try UUID lookup
            try:
                animal_uuid = uuid.UUID(clean_digits)
                animal_query_uuid = await db.execute(select(Animal).where(Animal.id == animal_uuid))
                animal = animal_query_uuid.scalars().first()
            except ValueError:
                animal = None

        # CRITICAL OWNERSHIP VALIDATION
        if animal is None or str(animal.farmer_id) != farmer_id_str:
            logger.warning(
                "ivr_animal_ownership_violation",
                extra={"call_sid": call_sid, "farmer_id": farmer_id_str, "digits": clean_digits},
            )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "ANIMAL_OWNERSHIP_VIOLATION",
                        "message": "Animal ear tag invalid or does not belong to the selected farmer.",
                        "details": {},
                    }
                },
            )

        session["animal_id"] = str(animal.id)
        session["current_stage"] = "symptom_1"
        await ExotelSessionStore.save_session(redis, session)
        logger.info("ivr_animal_identified", extra={"call_sid": call_sid, "animal_id": str(animal.id)})
        return {"status": "success", "stage": "animal_id", "animal_id": str(animal.id)}

    # -------------------------------------------------------------------------
    # Stage D: SYMPTOMS 1 THROUGH 5
    # -------------------------------------------------------------------------
    if stage_norm in SYMPTOM_STAGE_MAP:
        if clean_digits not in ("1", "2"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"error": {"code": "INVALID_INPUT", "message": "Symptom response must be 1 (Yes) or 2 (No).", "details": {}}},
            )

        symptom_key = SYMPTOM_STAGE_MAP[stage_norm]
        is_positive = (clean_digits == "1")
        session["symptoms"][symptom_key] = is_positive
        session["current_stage"] = NEXT_STAGE_MAP[stage_norm]

        await ExotelSessionStore.save_session(redis, session)
        logger.info(
            "ivr_symptom_collected",
            extra={"call_sid": call_sid, "stage": stage_norm, "symptom": symptom_key, "value": is_positive},
        )
        return {"status": "success", "stage": stage_norm, "symptom": symptom_key, "value": is_positive}

    # -------------------------------------------------------------------------
    # Stage E: CONFIRMATION & REAL HEALTH CASE CREATION
    # -------------------------------------------------------------------------
    if stage_norm == "confirmation":
        if clean_digits == "2":
            # Restart flow: reset to farmer_id stage and clear symptoms
            session["current_stage"] = "farmer_id"
            session["symptoms"] = {
                "eating_problem": False,
                "fever": False,
                "respiratory_problem": False,
                "digestive_problem": False,
                "movement_or_visible_abnormality": False,
            }
            await ExotelSessionStore.save_session(redis, session)
            logger.info("ivr_confirmation_restarted", extra={"call_sid": call_sid})
            return {"status": "success", "stage": "confirmation", "action": "restart"}

        if clean_digits == "1":
            # IDEMPOTENCY CHECK
            existing_case_id = await ExotelSessionStore.get_created_case_id(redis, call_sid) or session.get("case_id")
            if existing_case_id:
                logger.info("ivr_case_already_created_idempotent", extra={"call_sid": call_sid, "case_id": existing_case_id})
                return {"status": "success", "stage": "confirmation", "case_id": existing_case_id, "already_applied": True}

            farmer_id_str = session.get("farmer_id")
            animal_id_str = session.get("animal_id")

            if not farmer_id_str or not animal_id_str:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={"error": {"code": "INCOMPLETE_SESSION", "message": "Farmer and Animal must be set before case creation.", "details": {}}},
                )

            # Build list of active symptoms
            active_symptoms = [k for k, v in session.get("symptoms", {}).items() if v]
            if not active_symptoms:
                active_symptoms = ["unspecified_ivr_symptom"]

            farmer_id_uuid = uuid.UUID(farmer_id_str)
            animal_id_uuid = uuid.UUID(animal_id_str)

            # Look up animal location for geography if available
            animal_obj_query = await db.execute(select(Animal).where(Animal.id == animal_id_uuid))
            animal_obj: Animal | None = animal_obj_query.scalars().first()
            case_location = animal_obj.location if animal_obj else _loc_to_geo(LocationIn(latitude=18.5204, longitude=73.8567))

            # 1. DB Mutation
            case = HealthCase(
                animal_id=animal_id_uuid,
                farmer_id=farmer_id_uuid,
                source="IVR",
                symptoms=active_symptoms,
                location=case_location,
                risk_level="HIGH" if len(active_symptoms) >= 2 else "MEDIUM",
                status="OPEN",
            )
            db.add(case)
            await db.flush()

            audit = AuditLog(
                actor_user_id=None,
                action="IVR_CASE_CREATED",
                entity_type="HEALTH_CASE",
                entity_id=case.id,
                meta={"call_sid": call_sid, "caller_number": caller_number, "symptoms_count": len(active_symptoms)},
            )
            db.add(audit)

            # 2. DB Commit
            await db.commit()

            # 3. Store idempotency keys & update session
            case_id_str = str(case.id)
            session["case_id"] = case_id_str
            session["current_stage"] = "completed"
            await ExotelSessionStore.save_session(redis, session)
            await ExotelSessionStore.set_created_case_id(redis, call_sid, case_id_str)

            # 4. Redis Event Publish (after commit)
            await event_bus.publish(
                event_type="CASE_CREATED",
                payload=_to_out(case).model_dump(mode="json"),
                source="IVR",
            )

            logger.info("ivr_case_created", extra={"call_sid": call_sid, "case_id": case_id_str})
            return {"status": "success", "stage": "confirmation", "case_id": case_id_str, "already_applied": False}

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "INVALID_INPUT", "message": "Confirmation digits must be 1 (create) or 2 (restart).", "details": {}}},
        )

    return {"status": "success"}
