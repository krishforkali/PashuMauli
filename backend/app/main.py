"""FastAPI application entry point for PashuMauli platform."""
import logging
import sys
from typing import Any

from fastapi import FastAPI, Response, status
from fastapi.middleware.cors import CORSMiddleware
from redis.asyncio import Redis
from sqlalchemy import text

from app.core.config import get_settings
from app.core.middleware import RequestIdAndLoggingMiddleware
from app.db.base import async_engine

settings = get_settings()

# Setup structured logging
logging.basicConfig(
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
    level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO),
    stream=sys.stdout,
)
logger = logging.getLogger("pashumauli.main")

app = FastAPI(
    title="PashuMauli Livestock Health Surveillance Platform",
    description="FastAPI Backend for PashuMauli (SIH Problem Statement 26128)",
    version="0.1.0",
    docs_url="/docs" if settings.APP_ENV != "production" else None,
    redoc_url="/redoc" if settings.APP_ENV != "production" else None,
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
