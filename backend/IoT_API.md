# ArecaSmart IoT irrigation API (prototype)

This API layer receives ESP32 sensor readings and issues rule-driven irrigation commands. The first version is for the local exhibition/prototype workflow.

## Safety and deployment boundaries

- Configure `ARECASMART_IOT_API_TOKEN` on the backend and send the same value as the `X-Device-Token` header from a trusted device/API client.
- Do not commit the token or place it in source control. Do not embed this shared device token in a distributed Flutter app. Before app-level pump control is enabled, verify Firebase ID tokens on the backend and authorize the authenticated user against the device's farm.
- Current readings, event history, commands and settings are held **in memory**, limited to 500 readings and 200 events per device. Restarting the backend clears them. Firestore/durable historical storage is a follow-up integration, not implemented by these routes.
- The 30% start, 45% stop, 30-minute interval, 30-second runtime and 60-second reading freshness settings are conservative **prototype defaults only**, not agronomic recommendations for arecanut. Calibrate the sensor and set thresholds/intervals for the real crop, soil, irrigation method and installation.
- This software endpoint does not replace physical emergency-stop wiring or safe relay/pump design. Keep the hardware fail-safe OFF on boot/network loss, use a suitable driver/relay and rated supply, and keep mains voltage out of the exhibition model.
- No physical hardware test has been performed as part of this change.

## Configure locally (PowerShell)

From the backend directory, set a development-only token in the current terminal session and start Uvicorn:

```powershell
$env:ARECASMART_IOT_API_TOKEN = "replace-with-a-long-random-development-token"
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Use the same token in the trusted ESP32 firmware as `DEVICE_TOKEN`. If the backend is unconfigured, IoT routes return HTTP 503 instead of silently exposing pump controls. Requests with a missing/incorrect token return HTTP 401.

## Endpoints

All paths below require `X-Device-Token`.

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/sensors/readings` | Validate and ingest a reading, then recalculate the pump command |
| GET | `/api/v1/devices/{device_id}/command` | ESP32 polling endpoint; returns `mode`, `pump_on`, and `emergency_stop` |
| POST | `/api/v1/devices/{device_id}/control` | Set automatic/manual mode or request manual pump ON/OFF |
| POST | `/api/v1/devices/{device_id}/emergency-stop` | Activate or clear the emergency stop |
| PATCH | `/api/v1/devices/{device_id}/settings` | Set moisture thresholds and run/freshness limits |
| GET | `/api/v1/devices/{device_id}/readings?limit=100` | Return recent bounded sensor history |
| GET | `/api/v1/devices/{device_id}/status` | Return latest reading, command, settings and recent events |

Device IDs must contain 1–80 characters from letters, digits, dot, underscore, colon or hyphen.

## Sensor reading example

```json
{
  "device_id": "ARECA_SENSOR_001",
  "farm_id": "FARM_001",
  "soil_moisture_percent": 24.5,
  "soil_moisture_raw": 2880,
  "temperature_c": 29.2,
  "humidity_percent": 68.0,
  "rainfall_mm": 0.0,
  "sensor_valid": true
}
```

Required fields: `device_id` and `soil_moisture_percent`. Soil moisture must be 0–100%; raw ADC is optional and must be 0–4095. Optional temperature, humidity and rainfall values have bounded ranges. The sensor firmware should send a current UTC timestamp (or omit `observed_at` and allow the backend to assign receipt time).

## Manual control example

```http
POST /api/v1/devices/ARECA_SENSOR_001/control
X-Device-Token: <configured token>
Content-Type: application/json

{"mode": "manual", "pump_on": true}
```

Turn off manually with `{"mode":"manual","pump_on":false}`. Switch back to rule-driven mode with `{"mode":"auto"}`. Auto mode computes pump state; it does not accept `pump_on:true`.

Emergency stop:

```json
{"active": true}
```

Clearing it with `{"active": false}` never directly starts the pump. The API waits for a new valid sensor reading after reset before normal manual/automatic logic can permit operation.

## Rule and safety behavior

1. Pump starts in OFF state.
2. Invalid, missing or stale readings block pump ON in both auto and manual modes.
3. Auto mode requests irrigation when soil moisture is at/below the configured start threshold and the minimum interval since the previous run has elapsed.
4. During an automatic run, irrigation continues until the stop threshold is reached. The stop threshold must be greater than the start threshold (hysteresis).
5. Emergency stop always forces OFF and clearing it does not issue a new ON request.
6. Maximum continuous runtime is enforced for auto and manual runs.
7. Automatic irrigation can be disabled through settings.
8. Every state change/reading creates a bounded in-memory event record.

The firmware must also implement local safety behavior for network loss and boot, because backend commands cannot stop a pump if the device cannot reach the API.
