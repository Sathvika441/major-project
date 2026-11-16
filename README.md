# ArecaSmart — AI and IoT-Based Arecanut Farm Management

ArecaSmart is a smart-farming application designed to support arecanut farmers with crop disease identification, farm and weather information, and sensor-assisted irrigation management. The project combines a Flutter mobile application, a FastAPI backend, a CNN-based disease classification model, Firebase services, and an ESP32-based IoT prototype.

## Project highlights

- **Arecanut disease detection:** Upload a crop image through the app and use the trained CNN model to classify it. The project evaluation reported **96% test accuracy** across **nine disease/healthy classes**. The backend returns the predicted class, confidence, and ranked class predictions.
- **Disease care guidance:** The backend provides corresponding crop-care guidance for supported disease classifications.
- **Farm management:** Create and manage farm profiles and associate registered IoT devices with the relevant farm.
- **Weather-aware irrigation decision support:** The app's irrigation decision engine considers soil moisture, crop age and growth stage, temperature, humidity, rainfall, weather context, forecast precipitation, evapotranspiration, and recent irrigation when producing a recommendation.
- **IoT sensor monitoring:** Receive soil-moisture readings and available environmental measurements from a registered ESP32 device. The app displays available telemetry and device connectivity information.
- **Automatic and manual pump control:** The IoT backend supports threshold-based automatic control and farmer-requested manual ON/OFF control, with an emergency-stop function and safety checks.
- **Sensor history:** When Firebase Admin/Firestore is configured, telemetry readings are persisted and can be retrieved by the authenticated app.

## System architecture

```text
Flutter Mobile Application
        |
        +---- Firebase Authentication / Firestore
        |
        +---- FastAPI Backend
        |       |
        |       +---- CNN Arecanut Disease Classifier
        |       +---- Disease Care Guidance
        |       +---- Weather Service
        |       +---- Authenticated IoT App API
        |
        +---- Farm, Device and Irrigation UI
                        |
                  FastAPI IoT API
                        |
                      ESP32
                        |
             Soil Moisture Sensor
                        |
                   Water Pump
```

The Flutter application uses Firebase authentication for user-facing operations. The ESP32 communicates with protected device endpoints using a server-configured device token. The device token is separate from the Firebase ID token and must never be embedded in the Flutter application.

## IoT irrigation workflow

1. The soil-moisture sensor is read by the ESP32.
2. The ESP32 sends telemetry to the backend using the protected sensor-reading endpoint.
3. The backend validates the device payload and evaluates the latest reading against the configured moisture thresholds and safety conditions.
4. In automatic mode, the backend calculates the pump target. In manual mode, the farmer can request pump ON or OFF through the authenticated app.
5. The ESP32 polls for its latest command and applies the backend-authoritative pump target. The firmware is designed to fail OFF when connectivity or command freshness checks fail.
6. The app displays the available device status, moisture reading, pump state, control mode, emergency-stop state, and sensor history.

The application also contains a weather-aware irrigation decision engine for recommendations. The current backend's physical pump automation uses configured soil-moisture thresholds and safety rules; weather-based recommendations should not be interpreted as proof that the backend automatically actuates the pump from a weather forecast.

### Irrigation safety

- Automatic control requires a valid and sufficiently fresh sensor reading.
- Moisture start/stop thresholds use hysteresis to reduce rapid pump switching.
- A minimum interval between automatic runs and a maximum continuous run time are enforced.
- Emergency stop forces the pump target OFF. Clearing the stop does not directly start the pump; a fresh reading is required before normal control resumes.
- Firmware-side runtime limits and fail-OFF behavior provide additional safeguards.

Default thresholds and run limits are demonstration settings, not agronomic recommendations. Calibrate them for the actual soil, sensor, crop, pump, and irrigation installation. Software emergency stop does not replace a physical emergency-stop switch or correctly rated electrical protection.

## Repository structure

| Path | Description |
|---|---|
| `frontend/` | Flutter application, screens, state management, repositories, and tests |
| `backend/` | FastAPI application, disease inference, weather service, IoT APIs, and backend tests |
| `ML model/` | Trained arecanut model and class-name metadata |
| `hardware/esp32/ArecaSmart_Irrigation.ino` | ESP32 reference firmware for telemetry and pump control |
| `backend/IoT_API.md` | IoT API, authentication, Firestore layout, and setup details |

## Getting started

### 1. Flutter application

Install Flutter and configure the required Firebase project for the app. From the repository root, run:

```powershell
cd frontend
flutter pub get
flutter analyze
flutter test
```

To run the application in Chrome:

```powershell
flutter devices
flutter run -d chrome
```

Use the appropriate device identifier if running on an Android device or another supported target.

### 2. FastAPI backend

Use Python compatible with the dependencies in `backend/requirements.txt`. From the repository root:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Configure the backend environment. Keep the Firebase service-account file and device token outside source control:

```powershell
$env:FIREBASE_PROJECT_ID = "your-firebase-project-id"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\path\firebase-admin-service-account.json"
$env:ARECASMART_IOT_API_TOKEN = "your-long-random-device-token"
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The Flutter app and backend must use the same Firebase project. The ESP32 must be configured with the same device token as `ARECASMART_IOT_API_TOKEN`. Never commit real credentials, tokens, service-account JSON, or local environment files. See [backend/IoT_API.md](backend/IoT_API.md) for endpoint details and the Firebase/IoT configuration.

### 3. ESP32 prototype

Open `hardware/esp32/ArecaSmart_Irrigation.ino` in the Arduino IDE, install the required board and libraries, and configure the Wi-Fi credentials, backend address, device ID, and device token for the test environment. Do not commit real Wi-Fi credentials or tokens.

The ESP32 firmware and the physical sensor/pump setup have been exercised as part of the project prototype. Validate the wiring, power supply, pump driver, sensor calibration, network behavior, and independent electrical safety measures before any field deployment.

## API and data notes

- ESP32 telemetry routes require `X-Device-Token`.
- Flutter app IoT routes require `Authorization: Bearer <Firebase ID token>` and verify that the device belongs to the signed-in user.
- When Firebase Admin/Firestore is configured, telemetry readings are persisted under `iot_devices/{deviceId}/readings`.
- Irrigation command state, settings, and event evaluation currently use bounded in-memory backend state. They reset to safe pump-OFF defaults after a backend restart; Firestore status snapshots do not currently restore the full command/settings state.
- Without Firebase Admin/Firestore configuration, authenticated app IoT endpoints and persisted history are unavailable.
- The ML model must be present at the path expected by `backend/app/ml_service.py` for disease inference to be available.

## Current implementation boundaries

ArecaSmart is an academic prototype and decision-support system. Model accuracy is based on the project's evaluation dataset and does not guarantee correct diagnosis for every field image. Disease guidance and irrigation recommendations should be reviewed against local agricultural expertise. IoT pump commands are subject to device connectivity, sensor validity, backend safety rules, and the physical installation; an API response alone is not proof of pump actuation.

## Contributing and validation

Keep this README aligned with the implementation when adding or changing features. Record the checks that were actually run, and distinguish implemented behavior from planned work. Before submitting changes, run the relevant Flutter or Python tests and review configuration/security changes for accidentally committed credentials.
