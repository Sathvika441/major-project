# ArecaSmart IoT API and Firebase integration

The backend accepts ESP32 telemetry, evaluates rule-driven irrigation safety conditions, and exposes separate endpoints for the ESP32 and the signed-in Flutter application.

## Security and storage

- The ESP32 uses the server-configured `ARECASMART_IOT_API_TOKEN` as `X-Device-Token`. Keep this secret out of source control.
- The Flutter app uses a Firebase ID token in `Authorization: Bearer <token>`. It must never contain or send the ESP32 device token.
- App endpoints verify the Firebase ID token and verify that the device's `deviceId` exists under `users/{uid}/devices`.
- When Firebase Admin is configured, readings are stored in `iot_devices/{device_id}` and `iot_devices/{device_id}/readings`. History survives backend restarts.
- **Current limitation:** irrigation commands, settings and event evaluation still use in-memory state. After a backend restart, the command state initializes with the pump OFF and settings return to defaults. Firestore stores readings and a status snapshot; it does not yet restore irrigation settings or command state.
- If Firestore is not configured, Firebase-authenticated app endpoints and persisted history are unavailable (HTTP 503).
- Default moisture thresholds and run limits are demonstration values, not agronomic advice. Calibrate sensors and validate thresholds for the actual crop, soil and irrigation system.
- Software emergency stop does not replace a physical emergency-stop switch, suitable pump driver, or correctly rated power supply. Hardware has not been physically tested.

## Configure the backend (PowerShell)

Install dependencies from the `backend` directory:

```powershell
pip install -r requirements.txt
```

Set the Firebase project ID, a service-account credential path kept outside the repository, and the ESP32-only token:

```powershell
$env:FIREBASE_PROJECT_ID = "your-firebase-project-id"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\path\firebase-admin-service-account.json"
$env:ARECASMART_IOT_API_TOKEN = "your-long-random-device-token"
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Use the same Firebase project in the Flutter app and backend. For deployment, prefer Application Default Credentials/workload identity over a downloaded service-account key. Never commit service-account JSON or real tokens. The template is in `backend/.env.example`.

## ESP32 endpoints

Every endpoint in this section requires `X-Device-Token`.

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/sensors/readings` | Validate and ingest a sensor reading |
| GET | `/api/v1/devices/{device_id}/command` | Return mode, pump target and emergency-stop state |
| POST | `/api/v1/devices/{device_id}/control` | Set auto/manual mode or request manual ON/OFF |
| POST | `/api/v1/devices/{device_id}/emergency-stop` | Activate or clear emergency stop |
| PATCH | `/api/v1/devices/{device_id}/settings` | Update thresholds and safety limits |
| GET | `/api/v1/devices/{device_id}/readings?limit=100` | Return recent in-memory readings |
| GET | `/api/v1/devices/{device_id}/status` | Return current command and device status |

## Flutter app endpoints

Every endpoint in this section requires `Authorization: Bearer <Firebase ID token>`. The backend verifies device ownership against the signed-in user's `users/{uid}/devices` collection.

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/app/devices/{device_id}/status` | Return current command, status and latest reading |
| GET | `/api/v1/app/devices/{device_id}/readings?limit=50` | Read persisted sensor history |
| POST | `/api/v1/app/devices/{device_id}/control` | Set mode or request manual pump control |
| POST | `/api/v1/app/devices/{device_id}/emergency-stop` | Activate or clear emergency stop |

Example manual pump request:

```http
POST /api/v1/app/devices/ARECA_SENSOR_001/control
Authorization: Bearer <Firebase ID token>
Content-Type: application/json

{"mode":"manual","pump_on":true}
```

A valid request does not guarantee that the pump will turn on. Invalid/stale readings, emergency stop, runtime limits and other safety gates can keep it OFF. Clearing emergency stop does not directly start the pump; a fresh sensor reading is required before normal control resumes.

## Firmware contract

Reference sketch: `hardware/esp32/ArecaSmart_Irrigation.ino`. It sends validated telemetry, polls the device-token command endpoint, treats backend `pump_on` as authoritative, and fails OFF when Wi-Fi or the last command becomes stale. It also has an independent local maximum runtime cap. This sketch has not been compiled or physically tested.

## Firestore layout

- Existing device registration/ownership: `users/{uid}/devices/{deviceDocumentId}` with a `deviceId` field matching the ESP32 `DEVICE_ID`.
- Current IoT snapshot: `iot_devices/{device_id}`.
- Durable sensor history: `iot_devices/{device_id}/readings/{autoId}`.

The backend uses Firebase Admin credentials and does not depend on client Firestore rules for these server-side writes. Configure Firestore access and backend credentials before enabling app controls.

## Local development status notes

The `/health` response reports `firestore_iot` and `iot` independently. `firestore_iot: enabled` means the Firebase Admin/Firestore client can be configured; it does not by itself prove that a particular user owns a device. `iot: unconfigured` means `ARECASMART_IOT_API_TOKEN` is unset or blank. Set this server-side token to a long random secret and configure the same value on the trusted ESP32; never embed it in Flutter or commit it to source control. Until this token is configured, ESP32 device-token routes remain disabled (HTTP 503).
