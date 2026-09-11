# Emergency Broadcast Specification

## Supported event types
- FLOOD_WARNING
- DISEASE_OUTBREAK
- EXTREME_WEATHER
- LIVESTOCK_MOVEMENT_RESTRICTION
- VACCINATION_CAMPAIGN
- CUSTOM_AUTHORIZED_ALERT

## Target selection
- district
- block
- radius
- polygon

Target geometry is validated server-side.

## Flow
Dashboard -> target preview -> authorization -> create broadcast -> PostGIS recipient query -> Redis jobs -> provider workers -> delivery callbacks -> dashboard status.

## Recipient eligibility
Only active, opted-in/authorized recipients appropriate to the channel. Apply duplicate suppression.

## Channels
MVP:
- SMS
- outbound IVR
- FCM

Optional:
- WhatsApp.

## Message localization
Store message variants by language. If a user's preferred language has no approved message, use an approved fallback or exclude that channel according to policy. Do not machine-generate emergency instructions without review.

## Queue
One job per recipient/channel. Retry transient failures with bounded exponential backoff. Do not retry permanent failures indefinitely.

## Delivery statuses
QUEUED
SENDING
SENT
DELIVERED
FAILED
CANCELLED

## Safety
- Role authorization.
- Confirmation dialog.
- Preview recipient count.
- Record exact message, target geometry, actor, time, and channel.
- Audit every broadcast.
- Support cancellation before dispatch where possible.
