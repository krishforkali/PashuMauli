# Third-Party Integrations

## Amazon Web Services / Bedrock
Purpose: Claude Code development and optional cloud AI.
Required runtime? No for core offline operation.
Config: AWS region, model ID, credentials/role.
Rule: keep behind AI service abstraction.

## PostgreSQL/PostGIS
Purpose: authoritative relational + geographic data.
Runtime required: yes.
Self-host locally for development; managed PostgreSQL/PostGIS can be used in production.

## Redis
Purpose: queue, cache, transient coordination.
Runtime required: yes for background broadcast jobs.

## Leaflet + OpenStreetMap-derived mapping
Purpose: dashboard maps.
Leaflet is frontend mapping library. Map tiles/data provider must be configurable.
Do not bulk-download or abuse public OSM tile infrastructure. Use an appropriate provider/self-hosted infrastructure for production.

## Exotel
Purpose: Indian telephony/IVR candidate.
Capabilities required:
- inbound call webhook
- recording/input handling as supported
- outbound call
- status callback
Provider adapter required.

## Twilio
Purpose: alternative/fallback telephony provider and development option where account/number availability permits.
Provider adapter required.

## MSG91
Purpose: India-focused SMS candidate.
Required adapter operations:
- send message
- delivery/status lookup/callback where available
- template handling
- error mapping

## Firebase Cloud Messaging
Purpose: smartphone push notifications.
Backend sends FCM messages; mobile receives them.
Do not treat FCM as an offline channel.

## Amazon S3
Purpose: object storage for images/documents/audio.
Store object key/metadata in PostgreSQL.
Use signed URLs or backend authorization for protected objects.

## Whisper-compatible STT
Purpose: IVR speech transcription.
Must support the selected languages sufficiently for the demo.
Wrap behind `SpeechToTextProvider`.

## TTS
Candidate: Amazon Polly or provider-native telephony TTS.
Must support required Hindi/Marathi demo voice path after validation.
Wrap behind `TextToSpeechProvider`.

## ngrok / Cloudflare Tunnel
Development/demo only. Not part of production architecture.

## GitHub
Source control and optional CI.

## Optional monitoring
Firebase Crashlytics for mobile and/or Sentry for backend/dashboard. Choose one approach; do not duplicate without reason.

## Optional WhatsApp
WhatsApp Business Platform can be added later. Emergency MVP must not depend on it.

## Provider failure policy
If a provider is unavailable:
- mark delivery failed/retry where transient.
- keep broadcast record.
- show provider health/error.
- never falsely report delivery success.
