"""FastAPI application entry point for PashuMauli platform."""
import logging
import asyncio
import logging
import sys
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from redis.asyncio import Redis
from sqlalchemy import text
from starlette.exceptions import HTTPException as StarletteHTTPException

import app.models as _models  # noqa: F401  Ensure all SQLAlchemy models are registered
from app.api.v1.router import api_v1_router
from app.api.v1.ws import redis_listener
from app.core.config import get_settings
from app.core.middleware import RequestIdAndLoggingMiddleware
from app.db.base import async_engine
from app.services.event_bus import event_bus

settings = get_settings()

# Setup structured logging
logging.basicConfig(
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
    level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO),
    stream=sys.stdout,
)
logger = logging.getLogger("pashumauli.main")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await event_bus.connect()
    task = asyncio.create_task(redis_listener())
    yield
    # Shutdown
    task.cancel()
    await event_bus.disconnect()

app = FastAPI(
    title="PashuMauli Livestock Health Surveillance Platform",
    description="FastAPI Backend for PashuMauli (SIH Problem Statement 26128)",
    version="0.1.0",
    docs_url="/docs" if settings.APP_ENV != "production" else None,
    redoc_url="/redoc" if settings.APP_ENV != "production" else None,
    lifespan=lifespan,
)

# Standardized Error Handlers (DOCS/API_CONTRACTS.md: {"error": {"code": "...", "message": "...", "details": {}}})
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(_: Request, exc: StarletteHTTPException) -> JSONResponse:
    if isinstance(exc.detail, dict) and "error" in exc.detail:
        return JSONResponse(status_code=exc.status_code, content=exc.detail)
    elif isinstance(exc.detail, dict):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": {
                    "code": exc.detail.get("code", "ERROR"),
                    "message": exc.detail.get("message", str(exc.detail)),
                    "details": exc.detail.get("details", {}),
                }
            },
        )
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": "HTTP_ERROR" if exc.status_code != 401 else "INVALID_CREDENTIALS",
                "message": str(exc.detail),
                "details": {},
            }
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "Validation failed.",
                "details": exc.errors(),
            }
        },
    )


# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request ID & Logging Middleware
app.add_middleware(RequestIdAndLoggingMiddleware)

# API v1 routes (Phase 2: auth, farmers, animals, cases)
app.include_router(api_v1_router)


@app.get("/health", status_code=status.HTTP_200_OK)
async def health() -> dict[str, str]:
    """Basic liveness probe."""
    return {"status": "ok", "app": "PashuMauli"}


@app.get("/ready")
async def ready(response: Response) -> dict[str, Any]:
    """Readiness probe checking database and redis connectivity."""
    db_status = "unknown"
    redis_status = "unknown"
    is_ready = True

    # 1. Check Database
    try:
        async with async_engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        db_status = "connected"
    except Exception as exc:
        db_status = f"unavailable: {str(exc)}"
        is_ready = False
        logger.error(f"Readiness check failed for database: {exc}")

    # 2. Check Redis
    try:
        redis_client = Redis.from_url(settings.REDIS_URL, decode_responses=True)
        await redis_client.ping()
        await redis_client.aclose()
        redis_status = "connected"
    except Exception as exc:
        redis_status = f"unavailable: {str(exc)}"
        is_ready = False
        logger.error(f"Readiness check failed for redis: {exc}")

    if not is_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {
            "status": "degraded",
            "database": db_status,
            "redis": redis_status,
        }

    return {
        "status": "ready",
        "database": db_status,
        "redis": redis_status,
    }
