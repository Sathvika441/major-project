# ArecaSmart — Smart Arecanut Farm Management and Disease Detection System

## 1. Project Overview

**ArecaSmart** is a smart agriculture application developed for arecanut farm management. The system combines:

- farmer authentication and profile management,
- multi-farm management,
- structured Karnataka farm-location selection,
- crop-age and growth-stage tracking,
- simulated agricultural sensor readings,
- weather information,
- explainable irrigation recommendations,
- image-based arecanut disease detection using a trained TensorFlow/Keras model, and
- a Flutter dashboard that brings these functions together.

The project is implemented as a **Flutter frontend + FastAPI backend + TensorFlow/Keras ML service**, with Firebase Authentication and Cloud Firestore used for application data.

> **Report note:** This README documents the implementation currently present in the repository. Dataset size, exact dataset source, measured accuracy values, and hardware specifications should only be added to the final report when those details are available from the project's actual dataset/training records.

---

# 2. Problem Statement

Arecanut farmers need timely information about farm conditions, irrigation requirements, weather conditions, and visible crop diseases. In a conventional workflow, these activities can be separated across manual observation, external weather information, and individual farm records.

ArecaSmart addresses this problem by providing a single application through which a farmer can:

1. maintain farm information,
2. monitor simulated sensor conditions,
3. view weather information for the selected farm,
4. receive irrigation recommendations, and
5. upload an arecanut image for ML-based disease classification.

The system is intended as a **decision-support application**. It does not claim to replace agricultural experts, laboratory diagnosis, or professional treatment advice.

---

# 3. Aim

The aim of the project is to develop an integrated smart agriculture application for arecanut cultivation that combines farm information, environmental data, irrigation decision support, weather information, and machine-learning-based disease detection in a single user interface.

---

# 4. Objectives

The major objectives are:

- Provide secure farmer authentication.
- Maintain farmer profile and multiple farm records.
- Capture structured farm location information.
- Track arecanut crop age and growth stage.
- Provide simulated sensor readings for development and demonstration.
- Use farm and environmental information to generate irrigation recommendations.
- Retrieve weather information for the selected farm location.
- Detect selected arecanut diseases from uploaded images using a trained deep-learning model.
- Display prediction confidence and available treatment information.
- Provide meaningful validation and error messages.
- Separate frontend presentation, backend services, and ML inference for maintainability.
- Maintain a usable web dashboard for demonstration and future extension.

---

# 5. Scope

## 5.1 Included in the current implementation

- Flutter web application.
- Firebase Email/Password authentication.
- Google sign-in support.
- Firestore-backed farmer/farm/device data.
- Multi-farm management.
- Karnataka district/taluk/village selection data.
- Crop-age and growth-stage calculation/display.
- Simulated sensor readings.
- Irrigation recommendation engine.
- Weather lookup and forecast integration.
- Arecanut image upload.
- ML disease classification.
- Prediction confidence display.
- Basic disease-specific medicine information where configured.
- Backend API validation and error handling.

## 5.2 Not currently included

- Physical sensor hardware.
- Real pump/actuator control.
- Automatic physical irrigation.
- Laboratory confirmation of disease.
- A medical/agricultural prescription system.
- Native mobile deployment as the primary documented runtime.
- A production cloud deployment configuration.

The current sensor values are simulated, and irrigation is recommendation-oriented rather than physical actuator control.

---

# 6. System Architecture

The application follows a layered architecture:

```text
+------------------------------------------------------+
|                  Flutter Frontend                    |
|                                                      |
| Authentication | Farm Management | Dashboard        |
| Sensors        | Irrigation       | Weather          |
| Disease Upload | ML Result        | Profile          |
+---------------------------+--------------------------+
                            |
                            | HTTP/JSON + Multipart
                            v
+------------------------------------------------------+
|                    FastAPI Backend                   |
|                                                      |
| /health                                             |
| /api/v1/weather                                     |
| /api/v1/predict                                     |
| /api/v1/predict/image                               |
+----------------------+-------------------------------+
                       |
          +------------+------------+
          |                         |
          v                         v
+----------------------+   +---------------------------+
| Weather Service     |   | TensorFlow/Keras ML       |
| Open-Meteo          |   | Inference Service         |
+----------------------+   +---------------------------+
                                      |
                                      v
                           arecanut_model.keras
                           class_names.json

+------------------------------------------------------+
| Firebase                                             |
| Firebase Authentication + Cloud Firestore            |
+------------------------------------------------------+
```

### Architecture flow

1. The user interacts with the Flutter application.
2. Authentication is handled using Firebase Authentication.
3. Farm/application records are stored through Firestore repositories.
4. Flutter calls FastAPI for weather and ML functionality.
5. FastAPI resolves farm locations and obtains weather data from Open-Meteo.
6. For disease detection, Flutter uploads an image to FastAPI.
7. FastAPI validates the file and passes it to the ML inference service.
8. The trained Keras model produces class probabilities.
9. The predicted class and confidence are returned to Flutter.
10. Flutter displays the result to the farmer.

---

# 7. Technology Stack

## Frontend

| Technology | Purpose |
|---|---|
| Flutter | User interface and application framework |
| Dart | Frontend programming language |
| Riverpod | State management |
| GoRouter | Application navigation |
| Firebase Auth | Authentication |
| Cloud Firestore | Application data |
| HTTP | Backend API communication |
| File Picker | Image selection |
| Shared Preferences | Local/session-related persistence |
| PInput | OTP-style input UI |
| Google Fonts | UI typography |
| Intl | Formatting/localization utilities |

The frontend dependency configuration is maintained in `frontend/pubspec.yaml`.

## Backend

| Technology | Purpose |
|---|---|
| Python | Backend language |
| FastAPI | REST API framework |
| Uvicorn | ASGI server |
| TensorFlow/Keras | ML model loading and inference |
| NumPy | Numerical processing |
| Pillow | Image decoding/validation |
| python-multipart | Multipart file upload handling |

## External services

| Service | Purpose |
|---|---|
| Firebase Authentication | User authentication |
| Cloud Firestore | User/farm/application data |
| Open-Meteo Geocoding API | Farm-location coordinate resolution |
| Open-Meteo Forecast API | Current and forecast weather |

---

# 8. Major Functional Modules

## 8.1 Authentication Module

The application supports:

- Email/Password authentication.
- Google sign-in support.
- Firebase Authentication integration.
- Farmer profile data associated with authenticated users.
- Session restoration.

The application uses Firebase Authentication for account identity while Firestore stores application-specific user/farm information.

The project's current OTP flow is application-level/mock verification rather than Firebase Phone Authentication.

---

## 8.2 Farmer and Farm Management

The application supports multiple farms for a farmer.

Farm information includes fields such as:

- farm name,
- location,
- state,
- district,
- taluk,
- village,
- village code where available,
- farm size,
- crop,
- planting date,
- irrigation method, and
- crop-age/growth-stage information.

The application does not currently use a separate plot-management layer.

### Karnataka location data

The frontend contains:

```text
frontend/assets/Karnataka_Location_Master.json
```

The project uses structured Karnataka location information for district, taluk, and village selection.

The current project data contains the documented Karnataka master of:

- 31 districts,
- 240 taluks,
- 29,781 villages.

---

# 9. Crop Age and Growth Stage

The application derives the crop age from planting information and uses growth-stage categories.

The current growth-stage mapping is:

| Crop age | Growth stage |
|---|---|
| Less than 1 year | Establishment |
| 1 to less than 3 years | Young palm |
| 3 to less than 6 years | Juvenile / pre-bearing |
| 6 to less than 12 years | Bearing |
| 12 years or more | Mature bearing |

These stages are used as application inputs for dashboard information and irrigation decision support.

---

# 10. Sensor Module

The project currently uses a **simulated sensor service** rather than physical sensor hardware.

The simulated environment provides values such as:

- soil moisture,
- temperature,
- humidity,
- rainfall, and
- reading timestamp.

The purpose of the simulated sensor layer is to allow the complete application workflow to be demonstrated without requiring physical IoT hardware.

The architecture can be extended later to replace simulated readings with real sensor data.

---

# 11. Weather Module

Weather functionality is implemented in the FastAPI backend.

The backend uses Open-Meteo services for:

1. geocoding the farmer-selected location, and
2. retrieving weather and forecast information.

The location resolution process considers:

- village,
- taluk,
- district,
- state, and
- optional farmer-entered location text.

The service validates the administrative hierarchy before accepting a geocoded result and can fall back to district-level coordinates when a small village is not available in the geocoder.

### Weather information

The backend retrieves current and forecast values including:

- temperature,
- relative humidity,
- precipitation,
- rain,
- weather code,
- precipitation probability,
- evapotranspiration-related values,
- daily maximum/minimum temperature,
- daily precipitation,
- daily precipitation probability, and
- daily ET0.

The weather service caches resolved results for approximately 15 minutes.

---

# 12. Irrigation Decision Support

The application contains an irrigation decision engine that combines environmental and crop information.

Inputs include:

- soil moisture,
- crop age,
- growth stage,
- temperature,
- humidity,
- rainfall,
- current weather context,
- next-24-hour precipitation,
- next-24-hour precipitation probability,
- next-24-hour ET0,
- recent irrigation context, and
- observation time.

The system produces an irrigation recommendation and explanation rather than directly controlling a pump.

### Irrigation modes

The project defines application-level irrigation modes including:

- recommendation-only,
- automatic, and
- manual.

The dashboard currently uses the recommendation-oriented workflow.

### Important implementation note

The numerical decision logic is a **project-specific heuristic/decision engine**. Its weights and thresholds should not be presented in the report as an official CPCRI irrigation formula unless independently validated against an official source.

---

# 13. Machine Learning Disease Detection

## 13.1 Purpose

The ML subsystem classifies an uploaded arecanut image into one of the disease/health classes represented by the trained model.

The model is integrated into the backend rather than executed as a separate application process.

---

## 13.2 Model files

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

The backend loads:

```text
ML model/models/arecanut_model.keras
ML model/models/class_names.json
```

---

# 14. ML Classes

The current `class_names.json` contains the following nine classes:

1. `Healthy_Leaf`
2. `Healthy_Nut`
3. `Healthy_Trunk`
4. `Mahali_Koleroga`
5. `Stem_bleeding`
6. `bud borer`
7. `healthy_foot`
8. `stem cracking`
9. `yellow leaf disease`

The exact class names above should be preserved in the report because they correspond to the current model artifact.

---

# 15. ML Training Methodology

The training implementation is contained in:

```text
ML model/src/train.py
```

## 15.1 Dataset directory structure expected by training

```text
ML model/
└── dataset/
    ├── train/
    │   ├── <class-name>/
    │   └── ...
    └── test/
        ├── <class-name>/
        └── ...
```

The training script uses TensorFlow's `image_dataset_from_directory` loader.

The training dataset is split into:

- 80% training subset,
- 20% validation subset.

The test directory is evaluated separately.

A fixed random seed of **42** is used for the train/validation split.

---

# 16. Image Preprocessing and Augmentation

The model operates on:

```text
224 × 224 × 3
```

RGB images.

Training uses the following augmentation operations:

- Random horizontal flip.
- Random rotation of 0.1.
- Random zoom of 0.1.
- Random contrast adjustment of 0.1.

MobileNetV2 preprocessing is applied before feature extraction.

This same preprocessing requirement is respected by the trained model used for backend inference.

---

# 17. Transfer Learning Model

The training implementation uses:

**MobileNetV2 with ImageNet weights**

Configuration:

- input shape: `224 × 224 × 3`
- `include_top=False`
- ImageNet pretrained weights
- pretrained base initially frozen

The classification head contains:

1. Global Average Pooling.
2. Dropout with rate 0.3.
3. Dense output layer with `num_classes` units.
4. Softmax activation.

Conceptually:

```text
Input Image
    ↓
Data Augmentation
    ↓
MobileNetV2 Preprocessing
    ↓
MobileNetV2 Feature Extractor
    ↓
Global Average Pooling
    ↓
Dropout (0.3)
    ↓
Dense Layer
    ↓
Softmax
    ↓
Disease / Health Class
```

---

# 18. Model Training Configuration

The current training script uses:

| Parameter | Current value |
|---|---:|
| Image size | 224 × 224 |
| Batch size | 32 |
| Random seed | 42 |
| Optimizer | Adam |
| Learning rate | 0.0001 |
| Loss | Sparse categorical crossentropy |
| Metric | Accuracy |
| Epochs | 15 |
| Base model | MobileNetV2 |
| Dropout | 0.3 |

The exact training dataset size and resulting measured accuracy are not hard-coded in the README because those values depend on the dataset/training run and should be taken from the generated evaluation artifacts.

---

# 19. ML Evaluation

The training script evaluates the trained model on the test dataset and generates:

- test loss,
- test accuracy,
- classification report,
- confusion matrix,
- training/validation accuracy graph, and
- training/validation loss graph.

Expected output artifacts are:

```text
ML model/outputs/
├── accuracy.png
├── loss.png
├── confusion_matrix.png
└── classification_report.txt
```

### Report usage

For the final academic report, the following values should be copied from the actual generated artifacts:

- overall test accuracy,
- overall test loss,
- per-class precision,
- per-class recall,
- per-class F1-score,
- support/count per class,
- confusion matrix values,
- training accuracy,
- validation accuracy,
- training loss, and
- validation loss.

Do not insert estimated values into the report.

---

# 20. ML Inference Pipeline

The production application inference path is:

```text
Farmer
  ↓
Flutter Image Picker
  ↓
Image Thumbnail Preview
  ↓
Predict Button
  ↓
Multipart HTTP Request
  ↓
FastAPI /api/v1/predict/image
  ↓
File Validation
  ↓
Pillow/Keras Image Decoding
  ↓
Resize to 224 × 224 RGB
  ↓
Trained Keras Model
  ↓
Softmax Probabilities
  ↓
Argmax
  ↓
Predicted Class + Confidence
  ↓
Flutter Result Card
```

The backend also returns a ranked list of class predictions.

The standalone `predict.py` script is useful for command-line testing, but it does not need to be run separately when using the application.

---

# 21. Disease Detection User Workflow

The dashboard deliberately separates image selection from model execution.

1. Open the dashboard.
2. Locate **Arecanut disease detection**.
3. Select **Upload image**.
4. Choose a JPG, JPEG, PNG, or WEBP image.
5. Review the thumbnail.
6. Click **Predict**.
7. Flutter sends the image to the FastAPI backend.
8. The backend validates and decodes the image.
9. The TensorFlow/Keras model performs inference.
10. The backend returns the predicted class, confidence, and ranked predictions.
11. Flutter displays the result.
12. If treatment information exists for the predicted class, the configured medicine information is displayed.
13. **Clear** removes the image and prediction.

This workflow prevents an image from triggering inference immediately upon selection.

---

# 22. Disease Detection API

## Endpoint

```text
POST /api/v1/predict/image
```

The image is sent as a multipart form field named:

```text
file
```

### Supported formats

- JPG
- JPEG
- PNG
- WEBP

### Maximum size

```text
10 MB
```

### Example response structure

```json
{
  "filename": "sample.jpg",
  "prediction": "Healthy_Leaf",
  "confidence": 0.95,
  "predictions": [
    {
      "class_name": "Healthy_Leaf",
      "confidence": 0.95
    }
  ],
  "model": "arecanut_model.keras"
}
```

The numerical values above are illustrative response structure only; they are not a claimed model result.

---

# 23. Backend API Reference

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/health` | Checks backend and ML availability |
| GET | `/api/v1/weather` | Retrieves weather for farm location |
| POST | `/api/v1/predict` | Compatibility endpoint for simulated sensor features |
| POST | `/api/v1/predict/image` | Performs trained image-based disease prediction |

## Health endpoint

Expected successful response when the model is available:

```json
{
  "status": "ok",
  "ml": "ready"
}
```

If the backend is running but the model cannot be loaded, the health response reports ML availability as `unavailable`.

---

# 24. Backend Error Handling

The image endpoint validates the request before inference.

| HTTP status | Meaning |
|---:|---|
| 400 | Unsupported extension, empty upload, or invalid image |
| 413 | Image exceeds 10 MB |
| 503 | ML model or class-name artifact unavailable |
| 500 | Model inference failed |

The frontend converts these backend failures into user-visible error messages.

---

# 25. Frontend Dashboard

The dashboard combines:

- farm selection,
- farm summary,
- crop information,
- device/sensor status,
- environmental metrics,
- weather information,
- irrigation recommendation,
- alerts,
- disease detection, and
- navigation to farm/device/profile management.

The disease-detection section uses:

- bounded image preview,
- vertical Predict/Clear actions,
- explicit loading state,
- prediction result card, and
- error display.

---

# 26. UI and Rendering Stability

Flutter web can surface rendering assertions when widgets receive invalid or unconstrained layout configurations.

The current implementation includes several defensive changes:

- ML image preview uses a bounded fixed-height container.
- Image preview uses `Container` for decoration and clipping.
- Predict/Clear controls use a vertical layout.
- Result content uses a vertical layout.
- Farm crop-age display is null-safe.
- The dashboard avoids unnecessary unbounded image layouts.

The image preview specifically uses a decorated `Container`, because Flutter's `SizedBox` does not provide a `decoration` parameter.

If repeated `RenderBox`, `sliver_multi_box_adaptor`, or `mouse_tracker` assertions occur after hot reload, restart the Flutter web application after pulling the latest branch.

---

# 27. Data Storage

The project uses Cloud Firestore for application data.

The repository contains data/repository layers for areas such as:

- farmer information,
- farm information,
- devices, and
- irrigation audit records.

The ML model itself is stored as a repository artifact and is loaded by the backend from the project filesystem.

---

# 28. Irrigation Audit Trail

The dashboard can record irrigation recommendation decisions using an audit layer.

Recorded information includes items such as:

- decision identifier,
- decision type,
- action,
- status,
- reason,
- timestamp, and
- decision details.

The audit record is intended to provide traceability for recommendation events.

If audit persistence is unavailable, the dashboard can still keep the decision visible locally.

---

# 29. Repository Structure

```text
major-project/
│
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── ml_service.py
│   │   └── weather_service.py
│   ├── ml/
│   └── requirements.txt
│
├── frontend/
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   ├── models/
│   │   ├── repositories/
│   │   ├── services/
│   │   └── widgets/
│   ├── assets/
│   │   └── Karnataka_Location_Master.json
│   └── pubspec.yaml
│
├── ML model/
│   ├── dataset/
│   ├── models/
│   │   ├── arecanut_model.keras
│   │   └── class_names.json
│   ├── outputs/
│   └── src/
│       ├── train.py
│       ├── evaluate.py
│       └── predict.py
│
└── README.md
```

---

# 30. Local Development Setup

## 30.1 Development branch

Current development branch:

```powershell
git checkout feature/ml-disease-detection-ui
git pull origin feature/ml-disease-detection-ui
```

Feature work is kept off `main`.

---

## 30.2 Backend

From the repository root:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn app.main:app --reload
```

The backend normally runs at:

```text
http://127.0.0.1:8000
```

Health check:

```text
http://127.0.0.1:8000/health
```

---

## 30.3 Flutter

Open a second terminal:

```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

The local Flutter web application communicates with:

```text
http://127.0.0.1:8000
```

---

# 31. Normal Runtime

Only two application processes are normally required:

```text
Terminal 1
    FastAPI
       ↓
    TensorFlow/Keras model

Terminal 2
    Flutter web application
```

The ML model does **not** need to be started as a third process.

---

# 32. Optional Standalone ML Prediction

For command-line model testing, run the script from the ML model directory:

```powershell
cd "ML model"
python src\predict.py "C:\path\to\image.jpg"
```

This is important because the standalone script uses model paths relative to the `ML model` directory.

Normal application usage does not require this command.

---

# 33. Testing and Validation

The current implementation includes validation at multiple layers.

## Frontend validation

- File selection cancellation handling.
- Empty image data handling.
- Supported extension selection.
- 10 MB frontend size limit.
- Loading state during prediction.
- Clear/reset workflow.
- User-visible backend errors.

## Backend validation

- File extension validation.
- Empty upload validation.
- 10 MB request-size validation.
- Image decoding validation.
- Model artifact validation.
- Class-name/model output compatibility validation.
- ML inference exception handling.

## Model validation

The training implementation provides:

- test-set evaluation,
- classification report,
- confusion matrix,
- training/validation accuracy curves,
- training/validation loss curves.

---

# 34. Non-Functional Requirements

## Performance

- ML model artifacts are cached after loading in the backend.
- Weather responses are cached for approximately 15 minutes.
- Image uploads are size-limited.
- Flutter image previews use bounded dimensions.

## Reliability

- Backend validates model artifacts before declaring ML as ready.
- Invalid images are rejected before inference.
- API errors are converted into readable frontend messages.
- Weather failures are surfaced without crashing the dashboard.

## Maintainability

The project separates:

- UI,
- models,
- repositories,
- services,
- irrigation logic,
- backend APIs,
- weather service, and
- ML inference.

## Usability

The disease detection workflow explicitly separates:

```text
Upload → Preview → Predict → Result
```

rather than automatically running inference immediately after upload.

---

# 35. Security and Safety Considerations

- Authentication is delegated to Firebase Authentication.
- Firestore is used for application data.
- Uploaded images are validated before processing.
- File types are restricted.
- Upload size is restricted to 10 MB.
- The ML model runs on the backend rather than exposing model execution directly in the browser.
- Treatment information is presented as application-provided information and should not be treated as professional agricultural advice.

For production deployment, additional controls such as authenticated backend requests, stricter CORS configuration, rate limiting, secure secrets management, HTTPS, monitoring, and stronger Firestore security rules should be implemented and documented.

---

# 36. Current Limitations

1. Sensor readings are simulated rather than collected from physical IoT devices.
2. The irrigation system provides recommendations and does not control a physical pump.
3. Disease classification is limited to the nine classes represented in the current model.
4. Prediction quality depends on the training dataset and the similarity between uploaded images and training data.
5. Weather resolution depends on the availability and accuracy of the external geocoding service.
6. Small village locations may fall back to district-level weather coordinates when an exact geocoder match is unavailable.
7. Treatment information is only configured for selected predictions.
8. The repository currently documents the model training configuration but does not by itself establish a universally applicable field-level disease diagnosis.
9. The current project is primarily demonstrated through Flutter web and local FastAPI execution.

---

# 37. Future Enhancements

Potential future work includes:

- Integration with physical soil-moisture, temperature, humidity, and rainfall sensors.
- ESP32/Arduino/IoT gateway integration.
- Real-time device telemetry.
- Real pump/valve integration with safety controls.
- Mobile Android/iOS deployment.
- Push notifications for important farm events.
- Historical sensor charts and trend analysis.
- More arecanut disease classes.
- Larger and more diverse image datasets.
- Model fine-tuning and systematic hyperparameter optimization.
- Model versioning and automated evaluation.
- Confidence thresholds and human-review workflows.
- Improved disease treatment knowledge base.
- Secure production backend deployment.
- Role-based access control.
- Automated testing and CI/CD.
- More detailed irrigation optimization using historical observations.
- Offline support for selected farm information.

---

# 38. Suggested Academic Report Structure

The project implementation maps naturally to the following report chapters.

## Chapter 1 — Introduction

Include:

- agricultural context,
- arecanut cultivation context,
- problem statement,
- motivation,
- aim,
- objectives,
- scope,
- significance of the project.

## Chapter 2 — Literature / Existing System

Discuss:

- conventional farm monitoring,
- manual disease identification,
- irrigation decision support,
- IoT-based agriculture,
- machine-learning-based crop disease detection,
- limitations of existing approaches.

This chapter requires external academic sources and should not be fabricated from this README.

## Chapter 3 — Proposed System

Use this README's:

- architecture,
- objectives,
- functional modules,
- workflow,
- system components,
- data flow,
- API design.

## Chapter 4 — Requirements and Design

Document:

- functional requirements,
- non-functional requirements,
- software requirements,
- hardware requirements,
- system architecture,
- database/storage design,
- module design,
- API design,
- UI design.

## Chapter 5 — Machine Learning Methodology

Document:

- dataset source,
- dataset size,
- class distribution,
- preprocessing,
- augmentation,
- train/validation/test split,
- MobileNetV2 transfer learning,
- model architecture,
- optimizer,
- learning rate,
- loss function,
- epochs,
- batch size,
- evaluation metrics.

Only use measured dataset and evaluation values from the actual training artifacts.

## Chapter 6 — Implementation

Document:

- Flutter implementation,
- Firebase integration,
- Firestore repositories,
- FastAPI backend,
- weather integration,
- irrigation engine,
- ML inference service,
- disease upload UI,
- error handling.

## Chapter 7 — Results and Testing

Include actual:

- screenshots,
- API test results,
- model accuracy,
- precision,
- recall,
- F1-score,
- confusion matrix,
- training/validation graphs,
- application test cases,
- error-handling test cases.

## Chapter 8 — Conclusion and Future Scope

Summarize:

- implemented features,
- practical usefulness,
- current limitations,
- future IoT integration,
- future model improvements,
- production deployment possibilities.

---

# 39. Recommended Report Figures

The following figures can be generated or captured from the project for the academic report:

1. System architecture diagram.
2. Overall application workflow.
3. Authentication flow.
4. Farm registration/management flow.
5. Sensor-to-dashboard flow.
6. Weather data flow.
7. Irrigation decision flow.
8. ML training pipeline.
9. ML inference pipeline.
10. Disease detection UI — image upload.
11. Disease detection UI — prediction result.
12. Dashboard screenshot.
13. Farm management screenshot.
14. Weather/irrigation dashboard screenshot.
15. Training accuracy graph.
16. Training loss graph.
17. Confusion matrix.
18. Classification report table.
19. API request/response examples.
20. Repository/module architecture.

---

# 40. Important Report Data That Must Be Taken From Actual Project Artifacts

Before submitting the final report, verify and insert the actual values for:

- dataset name/source,
- total number of images,
- number of images per class,
- train/validation/test image counts,
- training hardware,
- training time,
- final training accuracy,
- final validation accuracy,
- test accuracy,
- test loss,
- precision per class,
- recall per class,
- F1-score per class,
- confusion matrix,
- model file size,
- average inference time, if measured.

These values should come from actual experiment logs, generated output files, or measured tests. They should not be guessed.

---

# 41. Current Disease Treatment Information

The frontend currently has configured treatment information for selected predictions.

For `Stem_bleeding`, the current application text is:

```text
Apply Tridemorph (0.1%) or Copper Oxychloride (5 g/L).
```

This is application-provided information and is not a substitute for professional agricultural diagnosis or treatment guidance.

For a formal report, treatment recommendations should be supported by appropriate agricultural references before being presented as authoritative recommendations.

---

# 42. Development Notes

- The trained ML model is part of the repository.
- The backend loads the model lazily and caches the loaded artifacts.
- Backend inference validates that the number of model output classes matches `class_names.json`.
- Images are converted to RGB and resized to 224 × 224 before inference.
- The application returns ranked prediction probabilities in addition to the top prediction.
- The frontend uses `file_picker` for image selection.
- The weather service uses Open-Meteo.
- Sensor data is simulated.
- Irrigation is recommendation-only in the current dashboard workflow.
- README documentation should be updated alongside significant implementation changes.

---

# 43. Quick Start

### Terminal 1 — Backend

```powershell
cd C:\Users\Spandu\projects\major-project\backend
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Terminal 2 — Frontend

```powershell
cd C:\Users\Spandu\projects\major-project\frontend
flutter clean
flutter pub get
flutter run -d chrome
```

### Health check

Open:

```text
http://127.0.0.1:8000/health
```

Expected when the ML artifacts load:

```json
{
  "status": "ok",
  "ml": "ready"
}
```

---

# 44. Project Status

The current branch contains the integrated:

- Flutter application,
- Firebase authentication/data layer,
- farm management,
- simulated sensor workflow,
- weather service,
- irrigation recommendation logic,
- FastAPI backend,
- trained arecanut disease model,
- image upload and prediction workflow,
- ML result display,
- backend validation/error handling, and
- report-oriented project documentation.

**Current development branch:**

```text
feature/ml-disease-detection-ui
```

`main` is not used for ongoing feature development.

---

## License / Academic Use

Add the project's actual license, college/university requirements, dataset license, and model/dataset attribution here before final submission if applicable.
