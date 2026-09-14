import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.config import get_settings
from app.services.event_bus import event_bus

logger = logging.getLogger("pashumauli.ws")

router = APIRouter(prefix="/ws", tags=["websocket"])
settings = get_settings()


class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"WebSocket connected. Total: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
            logger.info(f"WebSocket disconnected. Total: {len(self.active_connections)}")

    async def broadcast(self, message: str):
        # Broadcast string message to all connected clients
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception as e:
                logger.warning(f"Error sending message to client: {e}")
                disconnected.append(connection)

        for connection in disconnected:
            self.disconnect(connection)

manager = ConnectionManager()

# Background task to listen to Redis and broadcast to WebSockets
async def redis_listener():
    try:
        pubsub = await event_bus.subscribe()
        logger.info("Started Redis listener for WebSockets.")
        async for message in pubsub.listen():
            if message["type"] == "message":
                data = message["data"]
                # data is already a JSON string from Redis EventBus publish
                await manager.broadcast(data)
    except Exception as e:
        logger.error(f"Redis listener failed: {e}")
        # Could implement reconnection logic here if needed

def get_current_ws_user(token: str):
    """Authenticate WebSocket connection using JWT token or demo token."""
    if token in ("dashboard-demo-token", "demo-token"):
        return "dashboard-demo-user"
    try:
        from app.core.security import decode_token
        payload = decode_token(token)
        user_id: str | None = payload.get("sub")
        return user_id
    except Exception:
        return None


@router.websocket("")
async def websocket_endpoint(websocket: WebSocket, token: str):
    """WebSocket endpoint for dashboard real-time updates."""
    # Step 6: Authenticated endpoint
    user_id = get_current_ws_user(token)
    if not user_id:
        logger.warning("WebSocket connection rejected: invalid token.")
        await websocket.close(code=1008, reason="Invalid token")
        return

    await manager.connect(websocket)
    try:
        while True:
            # We don't expect messages from the dashboard yet, but keep the connection open
            _ = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)
