import uuid
from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field

class EventType(str, Enum):
    USER_REGISTERED = "USER_REGISTERED"
    USER_LOGIN = "USER_LOGIN"
    USER_LOGIN_FAILED = "USER_LOGIN_FAILED"
    
    FARMER_CREATED = "FARMER_CREATED"
    FARMER_UPDATED = "FARMER_UPDATED"
    
    ANIMAL_CREATED = "ANIMAL_CREATED"
    ANIMAL_UPDATED = "ANIMAL_UPDATED"
    
    CASE_CREATED = "CASE_CREATED"
    CASE_UPDATED = "CASE_UPDATED"
    
    AI_RESULT_AVAILABLE = "AI_RESULT_AVAILABLE"
    RISK_UPDATED = "RISK_UPDATED"
    ADVISORY_CREATED = "ADVISORY_CREATED"
    
    IVR_RECEIVED = "IVR_RECEIVED"
    IVR_CASE_CREATED = "IVR_CASE_CREATED"

class EventEnvelope(BaseModel):
    event_id: uuid.UUID = Field(default_factory=uuid.uuid4)
    event_type: EventType
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    source: str = Field(default="SYSTEM")
    actor: dict[str, Any] | None = None
    payload: dict[str, Any]
