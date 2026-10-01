# ArecaSmart 🌱

ArecaSmart is a smart agriculture application for arecanut farmers. It brings farm management, weather intelligence, device monitoring, irrigation recommendations, and AI-based arecanut disease detection into one farmer-facing application.

**Documented branch:** `integration/frontend-backend-ml`

---

## 1. What is ArecaSmart?

The application is designed around a simple idea:

> Give the farmer one workspace where farm information, environmental information, device information and crop-health information can be viewed together and used for better decisions.

The current application can:

- Authenticate users.
- Guide new users through required setup.
- Create and manage farms.
- Store farm location and crop information.
- Manage plots belonging to farms.
- Register farm devices/sensors.
- Show device status and available readings.
- Retrieve current and forecast weather for the selected farm.
- Use weather and farm/sensor information in an irrigation recommendation engine.
- Upload an arecanut image and run the trained TensorFlow/Keras disease-classification model.
- Maintain a farmer profile.
- Persist the light/dark theme preference.
- Provide responsive desktop and mobile navigation.

The application is currently a **decision-support and monitoring system**. It should not be understood as a completed autonomous irrigation controller merely because irrigation logic and device models exist in the codebase.

---

# 2. Technology stack

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | Flutter / Dart | Cross-platform farmer application |
| UI | Material 3 | Application interface |
| State | Riverpod | State/dependency management |
| Navigation | GoRouter | Route management and auth-aware redirects |
| Authentication | Firebase Authentication | User authentication |
| Database | Cloud Firestore | Profiles, farms, plots and devices |
| Backend | FastAPI / Python | Weather and ML API |
| ML | TensorFlow / Keras | Arecanut disease image classification |
| Image handling | Pillow / NumPy | Backend image preprocessing |
| Weather | Open-Meteo | Geocoding and forecast data |
| Local storage | Shared Preferences | Local application state/preferences |
| Location data | Karnataka location master JSON | Structured State → District → Taluk → Village selection |

---

# 3. High-level architecture

~~~text
                         ARECASMART
                              |
                    +---------+---------+
                    |                   |
                    v                   v
             Flutter Frontend       Firebase
                    |                   |
          +---------+---------+    +----+----------------+
          |         |         |    |                     |
       Dashboard  Farms    Devices  Authentication    Firestore
          |         |         |                            |
          +---------+---------+----------------------------+
                    |
                    | HTTP
                    v
              FastAPI Backend
                    |
             +------+------+
             |             |
             v             v
       TensorFlow/Keras  Open-Meteo
          ML model       Geocoding
             |           Forecast
             +-----+-------+
                   |
                   v
              Results back
              to Flutter
~~~

### Responsibility of each layer

**Flutter**
- Displays the application.
- Collects farmer input.
- Handles navigation and UI state.
- Reads/writes Firebase data through repositories.
- Calls the FastAPI backend for weather and image prediction.

**Firebase**
- Handles authentication.
- Stores cloud application data.
- Provides Firestore collections for profiles, farms, plots and devices.

**FastAPI**
- Acts as the backend boundary.
- Provides health checking.
- Resolves farmer-entered locations.
- Retrieves weather.
- Runs ML inference for uploaded images.

**TensorFlow/Keras**
- Loads the trained arecanut model.
- Classifies uploaded images into the nine configured classes.

**Open-Meteo**
- Converts farmer-entered place information into coordinates.
- Supplies current and forecast weather data.

---

# 4. Complete application flow

~~~text
Application launch
       |
       v
     Splash
       |
       +---- User not authenticated ----> Login / Signup
       |
       +---- User authenticated
                    |
                    v
              Setup checks
                    |
          +---------+---------+
          |         |         |
     Permissions Onboarding Farm details
          |         |         |
          +---------+---------+
                    |
                    v
                Dashboard
                    |
       +------------+-------------+----------------+
       |            |             |                |
       v            v             v                v
     Farms       Devices       Profile       Selected farm
                                                   |
                                  +----------------+----------------+
                                  |                |                |
                                  v                v                v
                              Weather        Irrigation        AI disease
                                              recommendation    detection
~~~

Existing authenticated users who have completed the required setup can go directly to the dashboard.

---

# 5. Authentication and routing

The main routes currently include:

- /splash
- /login
- /signup
- /forgot-password
- /verify-email
- /otp-verification
- /permission-setup
- /onboarding
- /farm-details
- /dashboard
- /farm/:farmId
- /farms
- /devices
- /profile

Routing is implemented in:

~~~text
frontend/lib/app/router.dart
~~~

The router watches authentication state and redirects users depending on whether they are:

- Loading authentication state.
- Unauthenticated.
- Waiting for email verification.
- Waiting for OTP verification.
- Completing required onboarding/setup.
- Fully authenticated.

This prevents an unauthenticated user from directly opening authenticated application pages.

---

# 6. Farm management

Farm data is stored in Cloud Firestore.

A farm can contain information such as:

- Farm name
- Location
- State
- District
- Taluk
- Village
- Village code
- Land survey number
- Farm size in acres
- Crop
- Arecanut cultivation type
- Soil type
- Planting date
- Water source
- Irrigation method
- Active/inactive status

The repository also supports plots belonging to a farm.

### Firestore structure

~~~text
users/
└── {userId}/
    └── farms/
        └── {farmId}/
            └── plots/
                └── {plotId}
~~~

The farm repository reads active farms using the isActive field.

### Planting-date history

When an existing farm's planting date is changed to another calendar date, the repository records:

- Previous planting date
- New planting date
- Time of the change
- Source of the change

This creates a history rather than silently losing the previous value.

---

# 7. Farm dashboard

The dashboard is the main farmer workspace.

For a selected farm it combines:

- Farm information.
- Location.
- Crop information.
- Crop age/growth stage.
- Weather.
- Irrigation recommendation.
- Device/sensor readings when available.
- Crop-health information.
- AI disease detection.
- Alerts/activity.

The dashboard is responsive.

### Desktop

Uses an adaptive sidebar/navigation rail.

### Mobile

Uses bottom navigation.

### Farm-specific navigation

When a user opens a particular farm, the screen provides contextual back navigation that follows actual navigation history.

The dashboard remains vertically scrollable. ML image upload/prediction state changes are handled so that the dashboard does not unexpectedly jump to another scroll position.

---

# 8. Weather system

Weather is intentionally routed through FastAPI.

~~~text
Flutter
   |
   | GET /api/v1/weather
   v
FastAPI
   |
   +--> Open-Meteo Geocoding API
   |        |
   |        +--> place -> latitude/longitude
   |
   +--> Open-Meteo Forecast API
            |
            +--> current weather
            +--> hourly forecast
            +--> daily forecast
   |
   v
Normalized weather response
   |
   v
Flutter weather card
~~~

The Flutter app sends:

- State
- District
- Taluk
- Village
- Optional location text

to the weather endpoint.

## Location resolution

The backend attempts to find the most specific usable location.

It can try:

1. Farmer-entered location text.
2. Village.
3. Taluk.
4. District.

The returned location is scored using the requested name and administrative hierarchy.

If a small village cannot be resolved reliably, the backend can fall back to a district-level coordinate rather than returning no weather data.

The response also reports the resolved level and coordinates.

## Weather data currently requested

### Current

- Temperature
- Relative humidity
- Precipitation
- Rain
- Weather code

### Next 24 hours

- Total precipitation
- Maximum precipitation probability
- ET0 / reference evapotranspiration

### Three-day forecast

- Maximum temperature
- Minimum temperature
- Precipitation
- Precipitation probability
- ET0
- Weather code

The backend caches weather responses for approximately 15 minutes per location.

### Weather source

Open-Meteo:

- https://open-meteo.com/en/docs
- https://open-meteo.com/en/docs/geocoding-api

The UI identifies the source as Open-Meteo.

---

# 9. Irrigation recommendation engine

The irrigation logic is implemented under:

~~~text
frontend/lib/core/irrigation/
~~~

The main decision engine is:

~~~text
irrigation_decision_engine.dart
~~~

It does not make a recommendation from one value alone. It combines multiple signals.

## Inputs

The engine can consider:

- Soil moisture
- Crop age
- Crop growth stage
- Temperature
- Humidity
- Rainfall
- Weather context
- Forecast precipitation for the next 24 hours
- Forecast precipitation probability
- Forecast ET0
- Recent irrigation activity

## Decision flow

~~~text
Farm information
   |
   +--> crop age
   +--> growth stage

Sensor information
   |
   +--> soil moisture

Weather information
   |
   +--> temperature
   +--> humidity
   +--> rainfall
   +--> forecast rain
   +--> rain probability
   +--> ET0

Recent irrigation
   |
   v
Input validation
   |
   v
Individual factors contribute to score
   |
   v
Score is clamped
   |
   v
Recommendation threshold is evaluated
   |
   +--> Irrigation recommended
   |
   +--> Irrigation not recommended
   |
   v
Reason + factors + confidence + suggested duration
~~~

The engine also returns the factors that contributed to the recommendation, making the result more explainable.

### Safety validation

The input model validates ranges for values such as:

- Soil moisture: 0–100
- Humidity: 0–100
- Temperature: -50–70 °C
- Rainfall: 0–2000 mm
- Crop age: non-negative

Invalid input blocks the irrigation recommendation.

### Current irrigation boundary

The application should currently be understood as **recommendation-only decision support**.

The irrigation model contains enums for recommendation-only, automatic and manual modes, but that does not mean physical automatic pump control is currently implemented.

---

# 10. AI arecanut disease detection

The trained model is located at:

~~~text
ML model/models/arecanut_model.keras
~~~

The class list is located at:

~~~text
ML model/models/class_names.json
~~~

## Current model classes

The current class_names.json contains nine classes:

1. Healthy_Leaf
2. Healthy_Nut
3. Healthy_Trunk
4. Mahali_Koleroga
5. Stem_bleeding
6. bud borer
7. healthy_foot
8. stem cracking
9. yellow leaf disease

These names are taken directly from the current model class configuration.

## Prediction pipeline

~~~text
Farmer selects image
       |
       v
Flutter checks image
       |
       | maximum 10 MB
       v
POST /api/v1/predict/image
       |
       v
FastAPI validates file
       |
       +--> extension check
       +--> empty file check
       +--> 10 MB size check
       |
       v
ML inference service
       |
       +--> load model/class names once
       +--> read image
       +--> convert to RGB
       +--> resize to 224 x 224
       +--> model.predict()
       |
       v
Prediction probabilities
       |
       +--> predicted class
       +--> confidence
       +--> ranked predictions
       |
       v
Flutter displays result
~~~

The ML service uses an in-process cache so the trained model is loaded once rather than from disk for every request.

### Preprocessing

The inference service resizes images to:

~~~text
224 × 224
~~~

The current code notes that MobileNetV2 preprocessing is already part of the trained model, so the backend does not apply a second external MobileNetV2 preprocessing operation.

### Important limitation

The model output is an AI classification result. Its confidence value is the model's prediction score; it should not be treated as a guaranteed field diagnosis.

---

# 11. FastAPI backend

Backend location:

~~~text
backend/
~~~

Main application:

~~~text
backend/app/main.py
~~~

ML service:

~~~text
backend/app/ml_service.py
~~~

Weather service:

~~~text
backend/app/weather_service.py
~~~

## API endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| GET | /health | Backend + ML availability |
| GET | /api/v1/weather | Farm location + weather |
| POST | /api/v1/predict | Feature-prediction interface for supplied feature data |
| POST | /api/v1/predict/image | Trained image disease prediction |

## Health endpoint

A healthy local setup can return:

~~~json
{
  "status": "ok",
  "ml": "ready"
}
~~~

If the backend is running but the model cannot be loaded:

~~~json
{
  "status": "ok",
  "ml": "unavailable"
}
~~~

## Image endpoint

Accepted image extensions:

- JPG
- JPEG
- PNG
- WEBP

Maximum size:

~~~text
10 MB
~~~

Typical error statuses:

| Status | Meaning |
|---|---|
| 400 | Invalid/unsupported/empty image |
| 413 | Image exceeds 10 MB |
| 500 | ML prediction failed |
| 503 | ML model/artifacts unavailable |

---

# 12. Firebase data structure

The current repositories use these Firestore paths:

~~~text
users/{userId}/profile/current

users/{userId}/farms/{farmId}

users/{userId}/farms/{farmId}/plots/{plotId}

users/{userId}/devices/{deviceId}
~~~

## Profile

Profile information is stored at:

~~~text
users/{userId}/profile/current
~~~

The profile contains information including:

- Name
- Phone
- Location
- State
- District
- Taluk
- Village
- Village code
- Language
- Notification preference
- Farm-related profile fields

A local copy is also maintained for profile/onboarding migration handling.

## Farms

Farm records are stored under the user's farms collection.

The farm repository returns active farms and supports:

- Read
- Stream/watch
- Save/update
- Deactivate

## Plots

Plots belong to farms.

~~~text
users/{userId}/farms/{farmId}/plots/{plotId}
~~~

## Devices

Devices are stored under:

~~~text
users/{userId}/devices/{deviceId}
~~~

The device repository supports retrieving, watching and registering devices.

---

# 13. Devices and sensors

The Devices & Sensors screen currently provides:

- Total device count.
- Online device count.
- Offline device count.
- Device registration.
- Farm assignment.
- Device information and available readings.

A new device requires:

- Device ID.
- Device name.
- Farm assignment.

The repository also validates an attached latest reading when one exists.

### Important boundary

Registering a device in Firestore is not the same thing as connecting physical hardware.

The current application contains the application-side device/sensor architecture, but a physical IoT deployment still requires the actual hardware communication layer, telemetry transport, authentication and device-side firmware/integration.

---

# 14. User profile and validation

The Profile screen loads existing values and records them as the current baseline.

The Save Changes action is only shown when a user actually changes a tracked value.

~~~text
Profile loaded
     |
     v
Compare current values with original values
     |
     +--> No difference -> no save action
     |
     +--> Difference -> Save Changes
                         |
                         v
                       Save
                         |
                         v
                  New values become baseline
~~~

Tracked profile changes include:

- Name
- Phone
- District
- Taluk
- Village
- Village code
- Language
- Notification preference

Phone changes also go through the application's phone verification flow.

---

# 15. Responsive navigation

The main navigation component is:

~~~text
frontend/lib/widgets/app_navigation_scaffold.dart
~~~

## Desktop

Uses an adaptive navigation rail/sidebar.

Destinations:

- Home
- Farms
- Devices
- Profile

## Mobile

Uses bottom navigation for the same main destinations.

## Contextual back navigation

Farm-specific pages can display a back button that uses actual navigation history instead of always sending the user to a fixed screen.

This is particularly important for:

~~~text
Farm list
   ↓
Particular farm
   ↓
Back
   ↓
Actual previous page
~~~

---

# 16. Theme system

The application supports:

- Light mode.
- Dark mode.

Theme state is managed through Riverpod and persisted locally.

Important files:

~~~text
frontend/lib/app/theme/app_theme.dart
frontend/lib/app/theme/theme_mode_controller.dart
~~~

The visual design uses a nature/agriculture-inspired palette with:

- Green primary colors.
- Sage tones.
- Earth/amber accents.
- Soft application surfaces.
- Material 3 components.
- Consistent cards, fields and buttons.

---

# 17. Karnataka location master

The frontend contains:

~~~text
frontend/assets/Karnataka_Location_Master.json
~~~

The location service loads this data at application startup.

It supports structured selection:

~~~text
State
  ↓
District
  ↓
Taluk
  ↓
Village
  ↓
Village code
~~~

This is used to reduce free-text location errors when creating farms or editing the profile.

The weather service still performs its own external geocoding because the local location master is primarily application selection data, not a weather-coordinate database.

---

# 18. Project structure

Important project structure:

~~~text
major-project/
│
├── frontend/
│   ├── lib/
│   │   ├── app/
│   │   │   ├── router.dart
│   │   │   └── theme/
│   │   │
│   │   ├── core/
│   │   │   ├── irrigation/
│   │   │   ├── services/
│   │   │   ├── storage/
│   │   │   ├── validators/
│   │   │   └── utils/
│   │   │
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── dashboard/
│   │   │   ├── devices/
│   │   │   ├── farm/
│   │   │   ├── onboarding/
│   │   │   └── profile/
│   │   │
│   │   ├── models/
│   │   ├── repositories/
│   │   ├── services/
│   │   └── widgets/
│   │
│   ├── assets/
│   │   └── Karnataka_Location_Master.json
│   │
│   ├── pubspec.yaml
│   └── firebase_options.dart
│
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── ml_service.py
│   │   └── weather_service.py
│   │
│   └── requirements.txt
│
├── ML model/
│   └── models/
│       ├── arecanut_model.keras
│       └── class_names.json
│
└── README.md
~~~

There are additional supporting files; the structure above highlights the parts needed to understand the application architecture.

---

# 19. Important Flutter dependencies

The current frontend uses packages including:

- flutter_riverpod
- go_router
- shared_preferences
- google_fonts
- intl
- firebase_core
- firebase_auth
- cloud_firestore
- permission_handler
- pinput
- crypto
- http
- file_picker

The authoritative dependency list is:

~~~text
frontend/pubspec.yaml
~~~

---

# 20. Backend dependencies

The backend requirements currently include:

~~~text
fastapi
uvicorn
python-multipart
numpy
tensorflow
pillow
~~~

The authoritative dependency list is:

~~~text
backend/requirements.txt
~~~

The ML model is served through the backend, so a separate ML server is not required for the current architecture.

---

# 21. Local development setup

## Prerequisites

Install:

- Flutter SDK.
- Dart SDK compatible with the Flutter version.
- Python 3.x.
- Git.
- A Firebase project/configuration.
- Chrome for Flutter web development, or an Android emulator/device for Android.

Check Flutter:

~~~powershell
flutter --version
~~~

Check Python:

~~~powershell
python --version
~~~

---

## Clone the project

~~~powershell
git clone https://github.com/Sathvika441/major-project.git
cd major-project
git checkout integration/frontend-backend-ml
~~~

---

# 22. Frontend setup

~~~powershell
cd frontend
flutter pub get
~~~

The application initializes Firebase during startup through:

~~~text
frontend/lib/firebase_options.dart
~~~

A new Firebase environment must have the appropriate Firebase project/platform configuration.

Do not commit private service-account credentials or other secret keys.

---

# 23. Backend setup

From the repository root:

~~~powershell
python -m venv .venv
~~~

Activate the environment:

~~~powershell
.venv\Scripts\Activate.ps1
~~~

Install dependencies:

~~~powershell
pip install -r backend/requirements.txt
~~~

Start FastAPI:

~~~powershell
python -m uvicorn backend.app.main:app --reload
~~~

Default local backend:

~~~text
http://127.0.0.1:8000
~~~

Interactive FastAPI documentation:

~~~text
http://127.0.0.1:8000/docs
~~~

---

# 24. Run the Flutter application

From frontend:

~~~powershell
cd frontend
flutter run -d chrome
~~~

For Android:

~~~powershell
flutter devices
flutter run
~~~

The backend URL is configurable through BACKEND_BASE_URL.

Current defaults:

~~~text
Flutter Web:
http://127.0.0.1:8000

Android emulator:
http://10.0.2.2:8000
~~~

Example:

~~~powershell
flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://YOUR_HOST:8000
~~~

---

# 25. Verify the backend

With FastAPI running, open:

~~~text
http://127.0.0.1:8000/health
~~~

Then open:

~~~text
http://127.0.0.1:8000/docs
~~~

The health endpoint is the quickest way to check whether the ML artifacts are available.

Expected local healthy result:

~~~json
{
  "status": "ok",
  "ml": "ready"
}
~~~

---

# 26. ML model requirements

The backend expects exactly:

~~~text
ML model/
└── models/
    ├── arecanut_model.keras
    └── class_names.json
~~~

When the backend loads the ML artifacts it verifies:

1. The model file exists.
2. class_names.json exists.
3. The class list is valid and non-empty.
4. The model output class count equals the class-name count.

If these checks fail, ML status becomes unavailable.

---

# 27. What is implemented vs what is not

This distinction is important for anyone continuing the project.

## Implemented

- Flutter application structure.
- Responsive UI.
- Authentication flow.
- Firebase Authentication integration.
- Firestore profile storage.
- Firestore farm storage.
- Firestore plot storage.
- Firestore device storage.
- Farm CRUD/business logic.
- Profile editing and dirty-state validation.
- Light/dark theme.
- Adaptive navigation.
- Farm-specific back navigation.
- FastAPI backend.
- Backend health check.
- Open-Meteo location resolution.
- Open-Meteo current weather.
- Open-Meteo forecast.
- Weather caching.
- TensorFlow/Keras disease inference.
- Nine-class arecanut disease classification.
- Image upload validation.
- Irrigation decision engine.
- Irrigation recommendation/audit models.

## Do not assume these are already fully implemented

- Physical IoT sensor communication.
- Live hardware telemetry simply because a device exists in Firestore.
- Automatic pump switching from the dashboard.
- Production-grade disease diagnosis.
- Production ML monitoring/retraining.
- Production deployment infrastructure.
- Complete offline-first operation.
- Automated hardware safety interlocks.

---

# 28. Current limitations

### Weather precision

Weather coordinates come from external geocoding. A very small village may not be available in the geocoder, so the backend can fall back to a district-level location.

### Sensor integration

The application has device/sensor models and monitoring UI, but a Firestore device record does not establish a physical sensor connection.

### Disease classification

The ML model only knows the nine configured classes. An image outside the training distribution can still receive a prediction, so the confidence value must be interpreted cautiously.

### Backend deployment

The current frontend defaults to local backend URLs. A deployed application needs a deployed FastAPI URL configured through BACKEND_BASE_URL.

### Production security

Production use requires appropriate Firebase security rules, deployment secrets, authentication configuration, API security and infrastructure hardening.

---

# 29. Troubleshooting

## FastAPI does not start

Run:

~~~powershell
python --version
pip install -r backend/requirements.txt
python -m uvicorn backend.app.main:app --reload
~~~

If TensorFlow fails to install/load, check the Python/TensorFlow compatibility of the environment being used.

## Flutter cannot connect to backend

1. Confirm FastAPI is running.
2. Confirm the correct backend URL.
3. For Chrome use 127.0.0.1:8000 when running locally.
4. For an Android emulator use 10.0.2.2:8000.
5. If using another machine, configure BACKEND_BASE_URL.

## ML says unavailable

Check:

~~~text
ML model/models/arecanut_model.keras
ML model/models/class_names.json
~~~

Then check:

~~~text
http://127.0.0.1:8000/health
~~~

## Image prediction fails

Check:

- JPG/JPEG/PNG/WEBP format.
- File is below 10 MB.
- Image is valid/openable.
- FastAPI is running.
- Model file exists.
- class_names.json exists.
- Model output count matches class_names.json.

---

# 30. Future development

Potential next development areas include:

- Real IoT sensor integration.
- Live sensor synchronization.
- Physical irrigation controller integration.
- Better field/land mapping.
- Historical farm analytics.
- Historical weather analysis.
- Crop-health trends.
- Farmer notifications.
- Improved disease-model evaluation.
- Model retraining/versioning.
- Production backend deployment.
- Automated testing and CI/CD.
- Offline/poor-network support.

These are future directions, not claims about functionality already present on this branch.

---

# 31. Developer workflow

When adding a feature:

~~~text
Understand user flow
        ↓
Identify Flutter screen/state
        ↓
Identify model/repository/service
        ↓
Decide Firebase vs FastAPI responsibility
        ↓
Add validation and error handling
        ↓
Implement UI/state changes
        ↓
Test locally
        ↓
Update README if behavior/architecture changes
        ↓
Commit with a meaningful message
~~~

For backend/ML changes, update this README whenever any of the following changes:

- API endpoint.
- Request/response format.
- ML model.
- Class names.
- Preprocessing.
- Environment variables.
- Firebase data structure.
- External API.
- Major user workflow.
- Known limitations.

---

# 32. Important files for new developers

### Application entry point

~~~text
frontend/lib/main.dart
~~~

### Routing

~~~text
frontend/lib/app/router.dart
~~~

### Main navigation

~~~text
frontend/lib/widgets/app_navigation_scaffold.dart
~~~

### Dashboard

~~~text
frontend/lib/features/dashboard/screens/dashboard_screen.dart
~~~

### Farm management

~~~text
frontend/lib/features/farm/screens/farm_management_screen.dart
frontend/lib/features/farm/screens/farm_details_screen.dart
~~~

### Devices

~~~text
frontend/lib/features/devices/screens/device_management_screen.dart
~~~

### Profile

~~~text
frontend/lib/features/profile/screens/profile_edit_screen.dart
~~~

### Backend

~~~text
backend/app/main.py
backend/app/weather_service.py
backend/app/ml_service.py
~~~

### Irrigation

~~~text
frontend/lib/core/irrigation/
~~~

### ML model

~~~text
ML model/models/arecanut_model.keras
ML model/models/class_names.json
~~~

### Location data

~~~text
frontend/assets/Karnataka_Location_Master.json
~~~

---

# 33. One-minute understanding of the project

If you are completely new to this repository, remember these five things:

**1. Flutter is the main application.**

It is where the farmer logs in, manages farms, views the dashboard, checks devices, edits the profile and uploads disease images.

**2. Firebase stores the application's user-side cloud data.**

Authentication is handled by Firebase Authentication. Firestore stores profiles, farms, plots and devices.

**3. FastAPI is the backend service.**

Flutter calls it for weather and ML inference.

**4. Open-Meteo provides weather.**

The backend first resolves the farmer's location to coordinates and then requests current/forecast weather.

**5. TensorFlow provides disease prediction.**

Flutter uploads an image to FastAPI. FastAPI validates it, loads the trained arecanut model, resizes the image to 224 × 224, runs inference and returns the predicted class and confidence.

So the core data flow is:

~~~text
Farmer
  ↓
Flutter
  ├── Firebase → profile / farms / plots / devices
  │
  └── FastAPI
        ├── Open-Meteo → weather
        └── TensorFlow → disease prediction
  ↓
Farmer sees information and recommendations
~~~

That is the current architecture of ArecaSmart on the integration/frontend-backend-ml branch.


---

# Guest Weather & Public Home Extension

The current branch also supports a public, no-login Home and Weather experience.

## Guest behaviour

```
App launch
  ↓
Public Home
  ↓
Foreground device location
  ↓
FastAPI /api/v1/weather?lat=...&lon=...
  ↓
Open-Meteo forecast
```

If device location is unavailable:

1. Last locally saved GPS location is tried.
2. Last manually selected Karnataka place is tried.
3. Shivamogga district is used as the configured default.
4. The user can choose State → District → Taluk → Village from Karnataka_Location_Master.json.

Only foreground location is requested; no background location permission is used.

## Authenticated farm weather

When a farmer opens a farm workspace, weather is requested from the farm's saved State/District/Taluk/Village/Location through the existing FarmRepository + BackendApi flow. The phone's guest GPS is not used as the farm's authoritative weather context.

## Weather API extension

GET /api/v1/weather now accepts either:

- Existing place fields: state, district, taluk, village, location
- Or coordinates: lat, lon

The backend requests current weather, 24 hourly records, seven daily records, ET₀ and named field-guidance inputs from Open-Meteo. Weather responses are cached in-process for about 15 minutes and coordinate cache keys are rounded to two decimal places.

Open-Meteo's public geocoding API is a forward location search API (place name → coordinates), not a reverse-geocoding API. For raw GPS requests ArecaSmart therefore keeps the coordinate context rather than inventing a district/locality result.

## Guidance heuristics

The backend calculates four field-operation guidance values:

- Spraying
- Drying produce
- Harvest and transport
- Irrigation

Thresholds are named constants in backend/app/weather_service.py and covered by backend/tests/test_weather_guidance.py. They are application heuristics for decision support, not agronomic guarantees.

## Public ML

POST /api/v1/predict/image remains unauthenticated. It keeps the 10 MB limit and JPG/JPEG/PNG/WEBP validation and now has a lightweight in-process per-IP limiter (12 requests per 60 seconds). A 429 response is returned when the limit is exceeded.

## Frontend weather files

- frontend/lib/features/home/screens/home_screen.dart
- frontend/lib/features/weather/screens/weather_screen.dart
- frontend/lib/features/weather/widgets/manual_location_picker.dart
- frontend/lib/core/services/device_location_service.dart
- frontend/lib/services/backend/weather_cache_service.dart
- frontend/lib/models/weather/weather_model.dart

## Run

Frontend:

```
cd frontend
flutter pub get
flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000
```

Android emulator:

```
cd frontend
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000
```

Backend:

```
python -m uvicorn backend.app.main:app --reload
```

Guidance tests:

```
python -m unittest backend.tests.test_weather_guidance
```
