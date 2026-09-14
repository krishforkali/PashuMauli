"""Database seed script for PashuMauli demo environment."""
import asyncio
import logging

from sqlalchemy import select

from app.core.security import hash_password
from app.db.base import AsyncSessionLocal
from app.models.health_case import HealthCase
from app.models.user import User, UserRole

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("pashumauli.seed")

async def seed_data():
    async with AsyncSessionLocal() as db:
        # 1. Seed Demo Command Center User (+919999999999 / password123)
        res = await db.execute(select(User).where(User.phone == "+919999999999"))
        user = res.scalar_one_or_none()
        if not user:
            logger.info("Creating demo user +919999999999...")
            user = User(
                name="Command Center Officer",
                phone="+919999999999",
                email="admin@pashumauli.gov.in",
                password_hash=hash_password("password123"),
                role=UserRole.SYSTEM_ADMIN.value,
                preferred_language="hi",
                is_active=True
            )
            db.add(user)
            await db.commit()
            logger.info("Demo user +919999999999 created successfully.")
        else:
            logger.info("Demo user +919999999999 already exists.")

        # 2. Seed Field Vet (+919876543210 / password123)
        res_vet = await db.execute(select(User).where(User.phone == "+919876543210"))
        vet = res_vet.scalar_one_or_none()
        if not vet:
            logger.info("Creating field vet +919876543210...")
            vet = User(
                name="Dr. Rajesh Kumar",
                phone="+919876543210",
                email="vet.rajesh@pashumauli.gov.in",
                password_hash=hash_password("password123"),
                role=UserRole.FIELD_VET.value,
                preferred_language="en",
                is_active=True
            )
            db.add(vet)
            await db.commit()
            logger.info("Field vet +919876543210 created.")

        # 3. Seed Sample Health Cases if table is empty
        cases_res = await db.execute(select(HealthCase))
        cases = cases_res.scalars().all()
        if not cases:
            logger.info("Seeding initial sample cases for dashboard map...")
            sample_cases = [
                HealthCase(
                    source="IVR_CALL",
                    symptoms=["Fever", "Salivation", "Blisters on feet"],
                    suspected_disease="Foot and Mouth Disease (FMD)",
                    confidence=0.89,
                    risk_score=85.0,
                    risk_level="HIGH",
                    status="OPEN",
                    location="SRID=4326;POINT(73.8567 18.5204)", # Pune
                    reported_by=user.id,
                ),
                HealthCase(
                    source="MOBILE_APP",
                    symptoms=["High Fever", "Skin Nodules", "Lethargy"],
                    suspected_disease="Lumpy Skin Disease (LSD)",
                    confidence=0.94,
                    risk_score=92.0,
                    risk_level="HIGH",
                    status="OPEN",
                    location="SRID=4326;POINT(74.0183 17.6805)", # Satara
                    reported_by=vet.id,
                ),
                HealthCase(
                    source="IVR_CALL",
                    symptoms=["Coughing", "Nasal Discharge"],
                    suspected_disease="Peste des Petits Ruminants (PPR)",
                    confidence=0.72,
                    risk_score=45.0,
                    risk_level="MEDIUM",
                    status="OPEN",
                    location="SRID=4326;POINT(73.7898 18.5679)", # Baner
                    reported_by=user.id,
                )
            ]
            for c in sample_cases:
                db.add(c)
            await db.commit()
            logger.info("Sample health cases seeded.")

if __name__ == "__main__":
    asyncio.run(seed_data())
