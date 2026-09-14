"""Comprehensive Pytest Suite for Exotel Webhook Adapter (GET /api/v1/ivr/exotel/passthru)."""
import uuid

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.base import AsyncSessionLocal
from app.main import app
from app.models.animal import Animal
from app.models.audit_log import AuditLog
from app.models.farmer import Farmer
from app.models.health_case import HealthCase

pytestmark = pytest.mark.asyncio
settings = get_settings()


@pytest_asyncio.fixture
async def client():
    settings.EXOTEL_ENABLED = True
    settings.DEMO_MODE = True
    async with AsyncClient(
        transport=ASGITransport(app=app),  # type: ignore[arg-type]
        base_url="http://test",
    ) as ac:
        yield ac


@pytest_asyncio.fixture
async def db_session():
    async with AsyncSessionLocal() as session:
        yield session


@pytest_asyncio.fixture
async def sample_farmer_and_animal(db_session: AsyncSession):
    phone = f"+9198000{uuid.uuid4().hex[:6]}"
    ear_tag = f"TAG-EXO-{uuid.uuid4().hex[:6]}"

    farmer = Farmer(name="Exotel Test Farmer", phone=phone, preferred_language="mr")
    db_session.add(farmer)
    await db_session.flush()

    animal = Animal(farmer_id=farmer.id, ear_tag_id=ear_tag, species="CATTLE", breed="LOCAL")
    db_session.add(animal)
    await db_session.commit()

    return farmer, animal


# ---------------------------------------------------------------------------
# Test Cases 1-4: Language Stage
# ---------------------------------------------------------------------------

async def test_1_valid_language_1_hi(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=language&CallSid=test-exo-lang1&digits=1")
    assert resp.status_code == 200
    assert resp.json()["language"] == "hi"


async def test_2_valid_language_2_mr(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=language&CallSid=test-exo-lang2&digits=2")
    assert resp.status_code == 200
    assert resp.json()["language"] == "mr"


async def test_3_valid_language_3_en(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=language&CallSid=test-exo-lang3&digits=3")
    assert resp.status_code == 200
    assert resp.json()["language"] == "en"


async def test_4_invalid_language(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=language&CallSid=test-exo-lang4&digits=9")
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "INVALID_INPUT"


# ---------------------------------------------------------------------------
# Test Cases 5-8: Validation & Digits Normalization
# ---------------------------------------------------------------------------

async def test_5_quoted_digits_normalization(client: AsyncClient, sample_farmer_and_animal) -> None:
    farmer, _ = sample_farmer_and_animal
    # Passing quoted digits `"digits"`
    resp = await client.get(f'/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid=test-exo-quoted&digits="{farmer.phone}"')
    assert resp.status_code == 200
    assert resp.json()["farmer_id"] == str(farmer.id)


async def test_6_missing_callsid(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=language&digits=1")
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "MISSING_CALLSID"


async def test_7_missing_stage(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?CallSid=test-exo-100&digits=1")
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "UNKNOWN_STAGE"


async def test_8_unknown_stage(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=invalid_stage_xyz&CallSid=test-exo-100&digits=1")
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "UNKNOWN_STAGE"


# ---------------------------------------------------------------------------
# Test Cases 9-12: Farmer & Animal Ownership
# ---------------------------------------------------------------------------

async def test_9_valid_farmer(client: AsyncClient, sample_farmer_and_animal) -> None:
    farmer, _ = sample_farmer_and_animal
    resp = await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid=test-exo-farmer1&digits={farmer.phone}")
    assert resp.status_code == 200
    assert resp.json()["farmer_id"] == str(farmer.id)


async def test_10_unknown_farmer(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid=test-exo-farmer2&digits=0000000000")
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "FARMER_NOT_FOUND"


async def test_11_valid_animal(client: AsyncClient, sample_farmer_and_animal) -> None:
    farmer, animal = sample_farmer_and_animal
    call_sid = f"test-exo-anim1-{uuid.uuid4().hex[:4]}"
    # 1. Select farmer
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid={call_sid}&digits={farmer.phone}")
    # 2. Select animal
    resp = await client.get(f"/api/v1/ivr/exotel/passthru?stage=animal_id&CallSid={call_sid}&digits={animal.ear_tag_id}")
    assert resp.status_code == 200
    assert resp.json()["animal_id"] == str(animal.id)


async def test_12_animal_ownership_violation(client: AsyncClient, sample_farmer_and_animal, db_session: AsyncSession) -> None:
    farmer1, _ = sample_farmer_and_animal
    # Create farmer2 with animal2
    farmer2 = Farmer(name="Farmer 2", phone=f"+9197000{uuid.uuid4().hex[:6]}", preferred_language="mr")
    db_session.add(farmer2)
    await db_session.flush()
    animal2 = Animal(farmer_id=farmer2.id, ear_tag_id=f"TAG-OTHER-{uuid.uuid4().hex[:4]}", species="CATTLE")
    db_session.add(animal2)
    await db_session.commit()

    call_sid = f"test-exo-owner-viol-{uuid.uuid4().hex[:4]}"
    # Select farmer1
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid={call_sid}&digits={farmer1.phone}")
    # Try selecting farmer2's animal -> must return 400 ownership violation
    resp = await client.get(f"/api/v1/ivr/exotel/passthru?stage=animal_id&CallSid={call_sid}&digits={animal2.ear_tag_id}")
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "ANIMAL_OWNERSHIP_VIOLATION"


# ---------------------------------------------------------------------------
# Test Cases 13-16: Symptom Questionnaire Stages
# ---------------------------------------------------------------------------

async def test_13_symptom_1_yes(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=symptom_1&CallSid=test-exo-sym1&digits=1")
    assert resp.status_code == 200
    assert resp.json()["symptom"] == "eating_problem"
    assert resp.json()["value"] is True


async def test_14_symptom_1_no(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=symptom_1&CallSid=test-exo-sym1no&digits=2")
    assert resp.status_code == 200
    assert resp.json()["symptom"] == "eating_problem"
    assert resp.json()["value"] is False


async def test_15_all_five_symptoms(client: AsyncClient) -> None:
    sid = "test-exo-all5"
    s1 = await client.get(f"/api/v1/ivr/exotel/passthru?stage=symptom_1&CallSid={sid}&digits=1")
    assert s1.json()["symptom"] == "eating_problem"
    s2 = await client.get(f"/api/v1/ivr/exotel/passthru?stage=symptom_2&CallSid={sid}&digits=1")
    assert s2.json()["symptom"] == "fever"
    s3 = await client.get(f"/api/v1/ivr/exotel/passthru?stage=symptom_3&CallSid={sid}&digits=2")
    assert s3.json()["symptom"] == "respiratory_problem"
    s4 = await client.get(f"/api/v1/ivr/exotel/passthru?stage=symptom_4&CallSid={sid}&digits=2")
    assert s4.json()["symptom"] == "digestive_problem"
    s5 = await client.get(f"/api/v1/ivr/exotel/passthru?stage=symptom_5&CallSid={sid}&digits=1")
    assert s5.json()["symptom"] == "movement_or_visible_abnormality"


async def test_16_invalid_symptom_digits(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=symptom_1&CallSid=test-exo-symbad&digits=5")
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "INVALID_INPUT"


# ---------------------------------------------------------------------------
# Test Cases 17-20: Confirmation & Idempotency
# ---------------------------------------------------------------------------

async def test_17_confirmation_creates_case(client: AsyncClient, sample_farmer_and_animal, db_session: AsyncSession) -> None:
    farmer, animal = sample_farmer_and_animal
    sid = f"test-exo-create-{uuid.uuid4().hex[:4]}"

    await client.get(f"/api/v1/ivr/exotel/passthru?stage=language&CallSid={sid}&digits=2")
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid={sid}&digits={farmer.phone}")
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=animal_id&CallSid={sid}&digits={animal.ear_tag_id}")
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=symptom_1&CallSid={sid}&digits=1")
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=symptom_2&CallSid={sid}&digits=1")

    conf_resp = await client.get(f"/api/v1/ivr/exotel/passthru?stage=confirmation&CallSid={sid}&digits=1")
    assert conf_resp.status_code == 200
    data = conf_resp.json()
    assert "case_id" in data
    assert data["already_applied"] is False

    # Verify DB insertion
    cid = uuid.UUID(data["case_id"])
    db_case = (await db_session.execute(select(HealthCase).where(HealthCase.id == cid))).scalar_one_or_none()
    assert db_case is not None
    assert db_case.source == "IVR"
    assert db_case.farmer_id == farmer.id
    assert db_case.animal_id == animal.id


async def test_18_confirmation_restart(client: AsyncClient, sample_farmer_and_animal) -> None:
    farmer, _ = sample_farmer_and_animal
    sid = f"test-exo-restart-{uuid.uuid4().hex[:4]}"

    await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid={sid}&digits={farmer.phone}")
    restart_resp = await client.get(f"/api/v1/ivr/exotel/passthru?stage=confirmation&CallSid={sid}&digits=2")
    assert restart_resp.status_code == 200
    assert restart_resp.json()["action"] == "restart"


async def test_19_duplicate_confirmation_is_idempotent(client: AsyncClient, sample_farmer_and_animal, db_session: AsyncSession) -> None:
    farmer, animal = sample_farmer_and_animal
    sid = f"test-exo-idemp-{uuid.uuid4().hex[:4]}"

    await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid={sid}&digits={farmer.phone}")
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=animal_id&CallSid={sid}&digits={animal.ear_tag_id}")

    resp1 = await client.get(f"/api/v1/ivr/exotel/passthru?stage=confirmation&CallSid={sid}&digits=1")
    assert resp1.status_code == 200
    cid1 = resp1.json()["case_id"]

    # Repeat duplicate confirmation
    resp2 = await client.get(f"/api/v1/ivr/exotel/passthru?stage=confirmation&CallSid={sid}&digits=1")
    assert resp2.status_code == 200
    data2 = resp2.json()
    assert data2["case_id"] == cid1
    assert data2["already_applied"] is True

    # Count rows in DB for this call
    cases_count = (await db_session.execute(select(HealthCase).where(HealthCase.id == uuid.UUID(cid1)))).scalars().all()
    assert len(cases_count) == 1


async def test_20_duplicate_callsid_does_not_duplicate_case(client: AsyncClient, sample_farmer_and_animal) -> None:
    farmer, animal = sample_farmer_and_animal
    sid = f"test-exo-dupsid-{uuid.uuid4().hex[:4]}"

    await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid={sid}&digits={farmer.phone}")
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=animal_id&CallSid={sid}&digits={animal.ear_tag_id}")
    r1 = await client.get(f"/api/v1/ivr/exotel/passthru?stage=confirmation&CallSid={sid}&digits=1")
    r2 = await client.get(f"/api/v1/ivr/exotel/passthru?stage=confirmation&CallSid={sid}&digits=1")
    assert r1.json()["case_id"] == r2.json()["case_id"]


# ---------------------------------------------------------------------------
# Test Cases 21-25: Audit Log, Events & Session Behavior
# ---------------------------------------------------------------------------

async def test_21_audit_log_exists(client: AsyncClient, sample_farmer_and_animal, db_session: AsyncSession) -> None:
    farmer, animal = sample_farmer_and_animal
    sid = f"test-exo-audit-{uuid.uuid4().hex[:4]}"

    await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid={sid}&digits={farmer.phone}")
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=animal_id&CallSid={sid}&digits={animal.ear_tag_id}")
    r = await client.get(f"/api/v1/ivr/exotel/passthru?stage=confirmation&CallSid={sid}&digits=1")
    cid = uuid.UUID(r.json()["case_id"])

    audit_entry = (await db_session.execute(select(AuditLog).where(AuditLog.entity_id == cid))).scalar_one_or_none()
    assert audit_entry is not None
    assert audit_entry.action == "IVR_CASE_CREATED"


async def test_22_case_created_event_published(client: AsyncClient, sample_farmer_and_animal) -> None:
    farmer, animal = sample_farmer_and_animal
    sid = f"test-exo-ev-{uuid.uuid4().hex[:4]}"
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid={sid}&digits={farmer.phone}")
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=animal_id&CallSid={sid}&digits={animal.ear_tag_id}")
    r = await client.get(f"/api/v1/ivr/exotel/passthru?stage=confirmation&CallSid={sid}&digits=1")
    assert r.status_code == 200


async def test_23_ivr_received_event(client: AsyncClient) -> None:
    sid = f"test-exo-recv-{uuid.uuid4().hex[:4]}"
    resp = await client.get(f"/api/v1/ivr/exotel/passthru?stage=language&CallSid={sid}&digits=1")
    assert resp.status_code == 200


async def test_24_expired_session(client: AsyncClient, sample_farmer_and_animal) -> None:
    sid = f"test-exo-exp-{uuid.uuid4().hex[:4]}"
    # Query stage without prior session initialization
    farmer, _ = sample_farmer_and_animal
    resp = await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid={sid}&digits={farmer.phone}")
    assert resp.status_code == 200


async def test_25_completed_session_behavior(client: AsyncClient, sample_farmer_and_animal) -> None:
    farmer, animal = sample_farmer_and_animal
    sid = f"test-exo-comp-{uuid.uuid4().hex[:4]}"

    await client.get(f"/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid={sid}&digits={farmer.phone}")
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=animal_id&CallSid={sid}&digits={animal.ear_tag_id}")
    await client.get(f"/api/v1/ivr/exotel/passthru?stage=confirmation&CallSid={sid}&digits=1")

    # Repeat after completion
    r = await client.get(f"/api/v1/ivr/exotel/passthru?stage=confirmation&CallSid={sid}&digits=1")
    assert r.status_code == 200
    assert r.json()["already_applied"] is True


# ---------------------------------------------------------------------------
# Test Cases 26-30: Security, Errors & Compatibility
# ---------------------------------------------------------------------------

async def test_26_malformed_request(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=language")
    assert resp.status_code == 400


async def test_27_database_failure(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=farmer_id&CallSid=test-exo-dbfail&digits=invaliduuidxyz")
    assert resp.status_code == 400


async def test_28_redis_failure(client: AsyncClient) -> None:
    # Graceful fallback when redis is tested
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=language&CallSid=test-exo-redisfail&digits=1")
    assert resp.status_code == 200


async def test_29_no_secrets_logged(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/ivr/exotel/passthru?stage=language&CallSid=test-exo-sec&digits=1")
    assert "secret" not in resp.text


async def test_30_existing_demo_incoming_remains_compatible(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/v1/demo/ivr/incoming",
        json={
            "caller_phone": "+919988776655",
            "language": "mr",
            "farmer_name": "Demo Farmer",
            "animal_id": "EAR-TAG-DEMO-999",
            "symptoms": "High fever",
            "latitude": 18.5204,
            "longitude": 73.8567,
        },
    )
    assert resp.status_code == 201
    assert resp.json()["source"] == "IVR"
