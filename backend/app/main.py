import logging

from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .ml_service import (
    ModelNotLoadedError,
    load_artifacts,
    predict_image,
)
from .weather_service import OpenMeteoWeatherService, WeatherServiceError


logger = logging.getLogger(__name__)
weather_service = OpenMeteoWeatherService()

app = FastAPI(
    title="Major Project Backend",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    """Check backend and ML model availability."""

    try:
        load_artifacts()
        ml_status = "ready"
    except Exception as exc:
        logger.warning("ML model unavailable: %s", exc)
        ml_status = "unavailable"

    return {
        "status": "ok",
        "ml": ml_status,
    }


@app.get("/api/v1/weather")
def get_weather(
    state: str = Query(..., min_length=2),
    district: str = Query(..., min_length=2),
    taluk: str = Query(..., min_length=2),
    village: str = Query(..., min_length=2),
):
    """Return current and forecast weather for a farmer-entered location."""

    try:
        return weather_service.get_weather(
            state=state,
            district=district,
            taluk=taluk,
            village=village,
        )
    except WeatherServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.post("/api/v1/predict")
async def run_feature_prediction(payload: dict):
    """Accept simulated sensor features.

    Disease prediction uses /api/v1/predict/image.
    """

    return {
        "detail": (
            "Feature prediction endpoint is available for simulated "
            "sensor data. Use /api/v1/predict/image for trained "
            "image disease prediction."
        ),
        "received_features": payload.get("features", {}),
    }


@app.post("/api/v1/predict/image")
async def run_image_prediction(
    file: UploadFile = File(...),
):
    """Predict arecanut disease from an uploaded image."""

    allowed_extensions = {".jpg", ".jpeg", ".png", ".webp"}
    filename = file.filename or ""

    extension = (
        "." + filename.rsplit(".", 1)[-1].lower()
        if "." in filename
        else ""
    )

    if extension not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail="Please upload a JPG, JPEG, PNG, or WEBP image.",
        )

    max_image_bytes = 10 * 1024 * 1024
    image_bytes = await file.read(max_image_bytes + 1)

    if not image_bytes:
        raise HTTPException(
            status_code=400,
            detail="The uploaded image is empty.",
        )

    if len(image_bytes) > max_image_bytes:
        raise HTTPException(
            status_code=413,
            detail="Image is too large. Please upload an image smaller than 10 MB.",
        )

    try:
        return predict_image(image_bytes, filename)
    except ModelNotLoadedError as exc:
        raise HTTPException(
            status_code=503,
            detail=str(exc),
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc
    except RuntimeError as exc:
        logger.exception("ML prediction failed for %s", filename)
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        ) from exc
