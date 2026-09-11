# IVR Specification

## Inbound call
Telephony provider -> signed webhook -> backend.

## State machine
WELCOME
-> LANGUAGE
-> LOCATION
-> ANIMAL_TYPE
-> SYMPTOMS
-> RECORD/CONFIRM
-> PROCESSING
-> CASE_CREATED
-> CONFIRMATION
-> END

Allow retry/reprompt for unrecognized input.

## Speech pipeline
Audio -> preprocessing -> speech-to-text -> language-aware symptom extraction -> structured case.

Store only audio required by the retention policy.

## Location
Prefer registered caller profile/location when reliable. Otherwise ask for district/village or route to manual follow-up. Never invent a precise location.

## Risk
Use the same backend risk engine as mobile reports.

## Dashboard
Case creation emits `HEALTH_CASE_CREATED` and appropriate alert events.

## Outbound emergency IVR
Backend worker -> provider -> farmer phone -> localized TTS message -> status callback.

## Provider abstraction
`TelephonyProvider` must expose:
- create_inbound_response
- start_outbound_call
- get_call_status
- validate_webhook
- terminate_call where supported

Implement Exotel and/or Twilio adapters without leaking provider-specific objects into domain logic.
