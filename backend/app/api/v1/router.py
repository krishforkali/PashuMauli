"""API v1 router — aggregates all sub-routers under /api/v1."""
from fastapi import APIRouter

from app.api.v1.routes.animals import router as animals_router
from app.api.v1.routes.auth import router as auth_router
from app.api.v1.routes.cases import router as cases_router
from app.api.v1.routes.demo_ivr import router as demo_ivr_router
from app.api.v1.routes.farmers import router as farmers_router
from app.api.v1.ws import router as ws_router

api_v1_router = APIRouter(prefix="/api/v1")

api_v1_router.include_router(auth_router)
api_v1_router.include_router(farmers_router)
api_v1_router.include_router(animals_router)
api_v1_router.include_router(cases_router)
api_v1_router.include_router(demo_ivr_router)
api_v1_router.include_router(ws_router)
