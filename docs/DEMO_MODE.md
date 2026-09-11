# Demo Mode

## Goal
Provide a reliable jury demonstration using real devices where possible, while retaining a local simulation fallback.

## Demo scenario A — registration
1. Dashboard open on laptop.
2. Flutter app open on Android phone.
3. Register test farmer.
4. Backend persists.
5. Dashboard receives `FARMER_REGISTERED`.
6. UI shows registration and map update.

## Demo scenario B — offline
1. Disable phone internet.
2. Add/update animal and create case.
3. Show OFFLINE indicator and pending queue.
4. Close/reopen app.
5. Data remains.
6. Re-enable internet.
7. Sync completes.
8. Dashboard updates.

## Demo scenario C — real IVR
1. Judge calls configured test number.
2. IVR greets in supported language.
3. Judge reports symptom.
4. STT/processing creates case.
5. Dashboard receives event.
6. Map shows case.
7. Case risk and source show IVR.

## Demo scenario D — emergency
1. Dashboard opens Emergency Broadcast.
2. Select demo radius/polygon.
3. Preview recipients.
4. Select SMS + voice.
5. Confirm.
6. Test phones receive configured alert.
7. Dashboard displays queued/sent/delivery status.

## Fallback
A `SIMULATE IVR` flow may inject a prerecorded/test transcript into the same case-creation service. It must not bypass business logic.

## Safety
Demo credentials and recipients are isolated. A visible DEMO MODE indicator prevents accidental production broadcasts.
