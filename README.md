# ArecaSmart — Arecanut Farm Management

ArecaSmart is a Flutter-based farm management application for arecanut growers. It combines farm management, Firebase authentication and Firestore data, simulated sensor readings, irrigation recommendations, weather information, and trained ML-based arecanut disease detection.

## Current Features

- Firebase Email/Password authentication and Google sign-in support.
- Farmer profile and multi-farm management.
- Structured Karnataka location master with district, taluk, and village data.
- Farm crop-age and growth-stage tracking.
- Simulated sensor readings for soil moisture, temperature, humidity, and rainfall.
- Explainable irrigation recommendations.
- Weather API integration through the FastAPI backend.
- Arecanut disease detection using the trained TensorFlow/Keras model.
- Image upload with thumbnail preview before prediction.
- Explicit **Predict** action so selecting an image does not immediately run the model.
- Disease label and confidence result display.
- Disease-specific medicine information where configured.
- Clear frontend and backend error messages for invalid uploads, oversized images, unavailable models, and prediction failures.

## Disease Detection Workflow

The disease-detection flow is:

1. Open **Arecanut disease detection** on the dashboard.
2. Click **Upload image**.
3. Select a JPG, JPEG, PNG, or WEBP image.
4. Review the image thumbnail.
5. Click **Predict**.
6. Flutter sends the image to the FastAPI endpoint.
7. The backend loads the trained Keras model and performs inference.
8. The dashboard displays the predicted disease label and confidence.
9. When treatment information is configured for the predicted disease, it is displayed below the prediction.
10. **Clear** removes the selected image and prediction so another image can be tested.

The model is executed by the backend. The standalone ML prediction script does not need to be run while using the application.

## ML Model

The trained model is stored in:

```text
ML model/
├── models/
│   ├── arecanut_model.keras
│   └── class_names.json
├── src/
│   ├── train.py
│   ├── evaluate.py
│   └── predict.py
```

The model uses 224 × 224 RGB images and the class names stored in `class_names.json`.

The training code uses MobileNetV2 preprocessing. Backend inference applies the same preprocessing before prediction.

### Supported disease/classes

The current class-name file contains:

- `Healthy_Leaf`
- `Healthy_Nut`
- `Healthy_Trunk`
- `Mahali_Koleroga`
- `Stem_bleeding`
- `bud borer`
- `healthy_foot`
- `stem cracking`
- `yellow leaf disease`

## Backend

The backend is a FastAPI application located in `backend/`.

### Main endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/health` | Checks backend and ML model availability |
| GET | `/api/v1/weather` | Returns weather data for a farmer-entered location |
| POST | `/api/v1/predict` | Accepts simulated sensor features |
| POST | `/api/v1/predict/image` | Runs trained disease prediction on an uploaded image |

The image endpoint accepts:

- JPG
- JPEG
- PNG
- WEBP

Uploaded images must be non-empty and smaller than 10 MB.

### Error handling

The image prediction API returns clear HTTP errors:

- **400** — unsupported file type, empty file, or invalid image data.
- **413** — image exceeds the 10 MB limit.
- **503** — trained ML model/artifacts are unavailable.
- **500** — image was accepted but model inference failed.

## Local Setup

### 1. Clone and select the development branch

Development for the current ML UI work is on:

```powershell
git checkout feature/ml-disease-detection-ui
git pull origin feature/ml-disease-detection-ui
```

Do not use `main` for feature development.

### 2. Backend setup

From the repository root:

```powershell
cd backend
..venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn app.main:app --reload
```

The backend uses:

- FastAPI
- Uvicorn
- TensorFlow
- NumPy
- Pillow
- python-multipart

Verify the backend:

```text
http://127.0.0.1:8000/health
```

Expected response when the trained model is available:

```json
{
  "status": "ok",
  "ml": "ready"
}
```

### 3. Flutter setup

In a second terminal:

```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

The Flutter web application uses the local backend at:

```text
http://127.0.0.1:8000
```

For the image picker, the frontend uses the `file_picker` package.

## Running the Application

Two processes are normally required:

```text
Terminal 1
FastAPI backend
    ↓
TensorFlow/Keras model

Terminal 2
Flutter web application
```

The ML model does **not** need to be started as a separate process. FastAPI loads the trained model when the backend handles ML requests.

## Repository Structure

```text
major-project/
├── backend/
│   ├── app/
│   ├── ml/
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   ├── assets/
│   └── pubspec.yaml
├── ML model/
│   ├── models/
│   └── src/
└── README.md
```

## Dashboard Layout Stability

The disease-detection card uses fixed, bounded image and vertical action layouts to avoid unconstrained web rendering. Farm-age display values are also null-safe so incomplete farm records do not trigger runtime layout exceptions.

If Flutter reports repeated `RenderBox`, `sliver_multi_box_adaptor`, or `mouse_tracker` assertions after a hot reload, stop the web app and restart it after pulling the latest branch changes.

## Development Notes

- Current sensor readings are simulated; no physical sensor hardware is required to run the dashboard.
- Disease prediction is image-based and uses the trained model included in the repository.
- Treatment/medicine text shown by the application is application-provided information associated with the predicted class; it should not be treated as a substitute for professional agricultural advice.
- Keep frontend, backend, ML model, and README changes synchronized when adding new features.
