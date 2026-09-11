# Notification Specification

## Notification service
Domain code calls a unified NotificationService. Provider adapters implement:
- SMSProvider
- PushProvider
- VoiceProvider
- optional WhatsAppProvider

## SMS
Use approved templates where required by provider/regulatory process.

## Push
FCM for smartphone application notifications.

## Voice
Outbound IVR uses telephony provider and localized TTS.

## Delivery
Every notification has:
- internal ID
- channel
- recipient reference
- provider message ID if available
- status
- attempts
- timestamps
- error code/message.

Never claim `DELIVERED` solely because an API accepted a send request; distinguish `SENT` from `DELIVERED`.
