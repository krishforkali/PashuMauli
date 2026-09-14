"""Typed configuration settings for PashuMauli backend."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    APP_ENV: str = "development"
    LOG_LEVEL: str = "INFO"
    DATABASE_URL: str = "postgresql://pashu:pashu@127.0.0.1:5432/pashumauli"
    REDIS_URL: str = "redis://127.0.0.1:6379/0"
    CORS_ORIGINS: str = "http://localhost:3000,http://127.0.0.1:3000,http://localhost:8000,http://127.0.0.1:8000"
    PUBLIC_BASE_URL: str = "http://localhost:8000"
    DEMO_MODE: bool = True

    # Authentication
    JWT_SECRET: str = "replace-with-local-secret"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRY: int = 3600
    JWT_REFRESH_TOKEN_EXPIRY: int = 604800
    RATE_LIMIT_AUTH_PER_MINUTE: int = 10

    # Storage
    STORAGE_PROVIDER: str = "mock"
    AWS_REGION: str = "ap-south-1"
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    S3_BUCKET: str = ""
    BEDROCK_MODEL_ID: str = ""

    # Telephony & Voice
    TELEPHONY_PROVIDER: str = "mock"
    EXOTEL_API_KEY: str = ""
    EXOTEL_API_TOKEN: str = ""
    EXOTEL_VIRTUAL_NUMBER: str = ""

    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_PHONE_NUMBER: str = ""

    MSG91_AUTH_KEY: str = ""
    MSG91_SENDER_ID: str = ""

    STT_PROVIDER: str = "mock"
    TTS_PROVIDER: str = "mock"

    # Push Notifications
    FIREBASE_PROJECT_ID: str = ""
    FCM_CREDENTIALS_PATH: str = ""

    # Outbreak Detection
    OUTBREAK_MIN_CASES: int = 3
    OUTBREAK_RADIUS_KM: float = 10.0
    OUTBREAK_WINDOW_DAYS: int = 14

    @property
    def sync_database_url(self) -> str:
        url = self.DATABASE_URL
        if url.startswith("postgresql+asyncpg://"):
            return url.replace("postgresql+asyncpg://", "postgresql+psycopg2://")
        if url.startswith("postgresql://"):
            return url.replace("postgresql://", "postgresql+psycopg2://")
        return url

    @property
    def async_database_url(self) -> str:
        url = self.DATABASE_URL
        if url.startswith("postgresql+psycopg2://"):
            return url.replace("postgresql+psycopg2://", "postgresql+asyncpg://")
        if url.startswith("postgresql://"):
            return url.replace("postgresql://", "postgresql+asyncpg://")
        return url

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
