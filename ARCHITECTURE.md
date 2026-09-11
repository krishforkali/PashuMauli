# PashuMauli Architecture

## System topology

```text
 Farmer/Vet Android
   Flutter + SQLite + TFLite
          |
          | HTTPS / sync
          v
     FastAPI Backend
       |     |      \
       |     |       \ WebSockets
       |     |        \
       v     v         v
 PostgreSQL PostGIS   Dashboard
       |
      Redis
       |
       +---- SMS Provider
       +---- Telephony Provider
       +---- FCM
       +---- optional WhatsApp

Feature Phone
    |
    v
Exotel/Twilio
    |
 webhook
    v
FastAPI -> STT -> case/risk -> PostgreSQL -> WebSocket -> Dashboard
```

## Deployment modes
### Local development
Backend/PostgreSQL/PostGIS/Redis can run through Docker Compose. Dashboard/mobile run locally.

### Physical-phone demo
Use a public tunnel to the local backend. Mobile app and telephony webhooks use the tunnel URL.

### Production
Deploy backend, PostgreSQL/PostGIS, Redis, object storage and dashboard to managed/cloud infrastructure. Use HTTPS/WSS and a stable domain.

## Design rules
- PostgreSQL is authoritative.
- Redis is not the permanent data store.
- WebSocket events do not replace REST/API reads.
- Mobile SQLite is authoritative only while disconnected; server wins for synchronized canonical state according to documented conflict rules.
- External services are adapters.
- Background workers perform slow/fan-out operations.
