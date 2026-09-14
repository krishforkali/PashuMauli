"""Redis-backed Event Bus for real-time WebSocket communication."""
import logging
from typing import Any

from redis.asyncio import Redis

from app.core.config import get_settings

logger = logging.getLogger("pashumauli.event_bus")

class RedisEventBus:
    """Manages Redis connection and Pub/Sub functionality."""

    def __init__(self):
        self.settings = get_settings()
        self.redis: Redis | None = None
        self.channel_name = "pashumauli_events"

    async def connect(self):
        """Initialize Redis connection."""
        if self.redis is None:
            self.redis = Redis.from_url(self.settings.REDIS_URL, decode_responses=True)
            logger.info("Connected to Redis Event Bus.")

    async def disconnect(self):
        """Close Redis connection."""
        if self.redis is not None:
            await self.redis.close()
            logger.info("Disconnected from Redis Event Bus.")

    async def publish(self, event_type: str, payload: dict[str, Any], actor: dict[str, Any] | None = None, source: str | None = None):
        """Publish an event to the Redis channel."""
        if self.redis is None:
            logger.warning("Event bus not connected. Cannot publish event.")
            return

        from app.schemas.events import EventEnvelope, EventType

        # Enforce valid event types
        try:
            e_type = EventType(event_type)
        except ValueError:
            logger.warning(f"Invalid event type: {event_type}")
            return

        envelope = EventEnvelope(
            event_type=e_type,
            payload=payload,
            actor=actor,
            source=source or "SYSTEM"
        )

        try:
            # We must dump using Pydantic's JSON serialization to handle datetimes and UUIDs
            message = envelope.model_dump_json()
            await self.redis.publish(self.channel_name, message)
            logger.debug(f"Published event {event_type} to Redis.")
        except Exception as e:
            logger.error(f"Failed to publish event {event_type}: {e}")

    async def subscribe(self):
        """Return a Redis pubsub object subscribed to the main channel."""
        if self.redis is None:
            raise RuntimeError("Event bus not connected.")

        pubsub = self.redis.pubsub()
        await pubsub.subscribe(self.channel_name)
        return pubsub

# Global singleton
event_bus = RedisEventBus()
