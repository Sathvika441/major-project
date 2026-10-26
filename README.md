# ArecaSmart — Smart Farm Workspace

ArecaSmart is a Flutter-based smart-farming application for organizing farms, viewing weather and crop information, monitoring registered IoT sensors, and managing irrigation controls where supported by a compatible controller/backend integration.

> **Project status:** Device registration and monitoring UI are implemented. Registering a device record does not by itself connect physical hardware. A device remains **Not connected** until valid telemetry is received. Pump commands are safety-gated and must not be treated as proof that a physical pump operated.

## Main features

- **Farm management:** Create and maintain farm details, including farm name, location, crop, acreage, and irrigation information.
- **Weather and farm workspace:** View farm-related weather information and workspace details.
- **Devices & sensors:** Register a device ID and display name, assign the device to a farm, and view its connectivity state and available readings.
- **Sensor telemetry:** Display soil moisture, temperature, humidity, and rainfall only when readings are available; the UI does not fabricate live readings.
- **IoT irrigation controls:** Show irrigation mode, pump state, moisture status, history, and safety messages. Actual operation depends on backend rules and compatible controller integration.
- **Crop health tools:** The repository includes an AI crop-image analysis flow backed by the backend service.

## Device-to-farm assignment

When registering a device, select the farm it belongs to. The device record stores the farm ID, and the Devices & Sensors card resolves that ID to the farm's saved name. Each card shows the assigned farm name and device ID. If the referenced farm cannot be found, the card displays **Farm not found** rather than guessing.

## Repository layout

- `frontend/` — Flutter application, screens, models, repositories, and tests.
- `backend/` — FastAPI service and related backend tests/services.
- `README.md` — Project overview, implementation notes, and recent changes.

## Development

### Flutter frontend

From the repository root:

```powershell
cd frontend
flutter pub get
flutter analyze
flutter test
```

Run the app on a supported device or browser using Flutter's device list, for example:

```powershell
flutter devices
flutter run -d chrome
```

### Backend

Backend setup depends on the Python environment and dependencies configured in `backend/`. On Windows PowerShell, activate the existing virtual environment from the backend directory if one has been created:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
```

Then follow the backend dependency and run instructions maintained in that directory. Do not run `cd backend` a second time when already inside the backend folder.

## Safety and data notes

- A registered Firestore/device record is not evidence that a physical sensor is online.
- Sensor values should only be displayed when valid telemetry is available.
- Irrigation/pump requests can be rejected by backend safety rules; UI status alone does not confirm physical actuation.
- Keep credentials, API keys, service-account files, and local environment files out of version control.

## Recent changes

### 2026-10-27 — Device farm name visibility

- Updated the Devices & Sensors cards to resolve each device's `farmId` against the user's saved farms.
- Added a visible **Farm: <farm name>** label and made the device ID explicit.
- Added a **Farm not found** fallback when the referenced farm record is unavailable.
- The device registration dialog continues to assign a device to a selected farm.
- Change committed on branch `feature/bug-fixes-improvements` (commit `e4af281`).
- Validation note: source was checked on GitHub; Flutter analysis/tests have not been run for this change.

### 2026-10-27 — Removed redundant onboarding screen

- Removed the separate onboarding screen that repeated farm-location entry already available in Farm Details.
- Removed the `/onboarding` route and changed the incomplete-profile redirect to `/farm-details`.
- Changes are on branch `feature/bug-fixes-improvements`; Flutter analysis/tests have not been run for this change.

### 2026-10-27 — Preserve farm association in IoT backend status

- Updated `backend/app/firestore_iot_store.py` to resolve the authoritative farm ID from the Flutter device registration path before saving IoT status.
- Persisted the resolved farm association as both `farmId` and `farm_id` at the IoT snapshot root, and as `farm_id` inside the backend status object, so existing Flutter and backend readers can consume the same relationship.
- Fixed a telemetry mapping path lookup to use the Firestore `DocumentReference.path` directly.
- This fixes the backend mapping path for future status writes; it does **not** automatically repair existing Firestore documents or generate sensor readings. Existing records may need a status refresh or a controlled data migration.
- Validation note: source was updated on GitHub; backend tests and lint/type checks have not been run.

### 2026-10-27 — Compact Devices & Sensors cards

- Reduced device-card padding, icon size, vertical spacing, and grid gaps.
- Combined the farm name and device ID into one compact metadata row.
- Removed the repeated “waiting for first telemetry packet” line; the no-reading state already communicates that no sensor data is available.
- Kept connection status, farm association, available sensor readings, and irrigation safety controls visible.
- Validation note: source was updated on GitHub; Flutter analysis/tests have not been run.

## Branch and contribution workflow

Current working branch for these improvements: `feature/bug-fixes-improvements`.

For each significant code change, update this README in the same commit or immediately afterward with:
1. What changed and why.
2. Relevant screen/API/model behavior.
3. Tests or checks actually run, including any that remain outstanding.

Do not describe a change as tested unless the relevant command or test was actually run.
