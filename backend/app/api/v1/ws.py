"""WebSocket router for real-time dashboard events."""
import asyncio
import json
import logging
from typing import Any

from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect, status
from jose import JWTError

from app.core.security import decode_token
from app.services.event_bus import event_bus

logger = logging.getLogger("pashumauli.ws")

router = APIRouter(prefix="/ws", tags=["websocket"])


async def authenticate_ws(token: str) -> dict[str, Any] | None:
    """Validate JWT token for WebSocket connection."""
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            return None
        if not payload.get("sub"):
            return None
        return payload
    except JWTError:
        return None


class ConnectionManager:
    """Manages active WebSocket connections."""
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in list(self.active_connections):
            try:
                await connection.send_text(message)
            except Exception:
                # Connection dropped
                self.disconnect(connection)

manager = ConnectionManager()

# Background task to listen to Redis and broadcast to WebSockets
async def redis_listener():
    while True:
        try:
            pubsub = await event_bus.subscribe()
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = message["data"]
                    # Broadcast the JSON string directly to all connected clients
                    await manager.broadcast(data)
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error(f"Redis listener failed: {e}. Retrying in 3s...")
            await asyncio.sleep(3)

@router.websocket("")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(...)):
    """Authenticated WebSocket endpoint for real-time events."""
    payload = await authenticate_ws(token)
    if not payload:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid or missing token")
        return

    await manager.connect(websocket)
    logger.info("websocket_connected", extra={"user_id": payload.get("sub"), "role": payload.get("role")})

    try:
        while True:
            # Keep connection open, client might send pings, we ignore them
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        logger.info("websocket_disconnected", extra={"user_id": payload.get("sub")})
    except Exception as e:
        manager.disconnect(websocket)
        logger.error(f"websocket error: {e}")
