import logging
import os
import secrets
import time
from collections import defaultdict, deque
from datetime import datetime, timezone
from typing import Literal

from fastapi import Depends, FastAPI, File, Header, HTTPException, Path, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field, model_validator

from .disease_guidance import care_guidance
from .irrigation_service import IrrigationService, as_utc, utc_now
from .ml_service import ModelNotLoadedError, load_artifacts, predict_image
from .weather_service import OpenMeteoWeatherService, WeatherServiceError

logger = logging.getLogger(__name__)
weather_service = OpenMeteoWeatherService()
irrigation_service = IrrigationService()
app = FastAPI(title="Major Project Backend", version="2.2.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

_PREDICT_WINDOW_SECONDS = 60
_PREDICT_MAX_REQUESTS = 12
_predict_hits = defaultdict(deque)


class SensorReadingIn(BaseModel):
    """Telemetry schema used by the ESP32 firmware."""

    model_config = ConfigDict(extra="forbid")

    device_id: str = Field(min_length=1, max_length=80, pattern=r"^[A-Za-z0-9._:-]+$")
    farm_id: str | None = Field(default=None, max_length=120)
    soil_moisture_percent: float = Field(ge=0, le=100)
    soil_moisture_raw: int | None = Field(default=None, ge=0, le=4095)
    temperature_c: float | None = Field(default=None, ge=-50, le=70)
    humidity_percent: float | None = Field(default=None, ge=0, le=100)
    rainfall_mm: float | None = Field(default=None, ge=0, le=2000)
    # These fields are also emitted by the current ESP32 sketch.
    pump_on: bool | None = None
    control_mode: Literal["auto", "manual"] | None = None
    timestamp_ms: int | None = Field(default=None, ge=0)
    sensor_valid: bool = True
    observed_at: datetime = Field(default_factory=utc_now)

    @model_validator(mode="after")
    def timestamp_must_be_reasonable(self):
        # Permit small device clock skew, but reject malformed/far-future timestamps.
        if (as_utc(self.observed_at) - utc_now()).total_seconds() > 60:
            raise ValueError("observed_at cannot be more than 60 seconds in the future.")
        return self


class DeviceControlIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    mode: Literal["auto", "manual"] | None = None
    pump_on: bool | None = None

    @model_validator(mode="after")
    def validate_control(self):
        if self.mode is None and self.pump_on is None:
            raise ValueError("Provide mode and/or pump_on.")
        if self.pump_on is not None and self.mode != "manual":
            raise ValueError("Specify mode='manual' when requesting manual pump ON/OFF.")
        return self


class EmergencyStopIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    active: bool


class IrrigationSettingsIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    start_moisture_percent: float = Field(default=30, ge=5, le=70)
    stop_moisture_percent: float = Field(default=45, ge=10, le=90)
    minimum_interval_minutes: int = Field(default=30, ge=0, le=1440)
    maximum_run_seconds: int = Field(default=30, ge=5, le=300)
    maximum_reading_age_seconds: int = Field(default=60, ge=5, le=300)
    automatic_enabled: bool = True

    @model_validator(mode="after")
    def stop_threshold_must_exceed_start(self):
        if self.stop_moisture_percent <= self.start_moisture_percent:
            raise ValueError("stop_moisture_percent must be greater than start_moisture_percent.")
        return self


def _require_device_token(x_device_token: str | None = Header(default=None, alias="X-Device-Token")):
    """Shared prototype credential; configure it on the server and ESP32."""
    expected = os.getenv("ARECASMART_IOT_API_TOKEN", "").strip()
    if not expected:
        raise HTTPException(
            status_code=503,
            detail="IoT API is disabled until ARECASMART_IOT_API_TOKEN is configured on the backend.",
        )
    if not x_device_token or not secrets.compare_digest(x_device_token, expected):
        raise HTTPException(status_code=401, detail="Missing or invalid X-Device-Token.")
    return True


def _check_rate_limit(request: Request):
    now = time.monotonic()
    key = request.client.host if request.client else "unknown"
    hits = _predict_hits[key]
    while hits and now - hits[0] > _PREDICT_WINDOW_SECONDS:
        hits.popleft()
    if len(hits) >= _PREDICT_MAX_REQUESTS:
        raise HTTPException(status_code=429, detail="Too many image predictions. Please wait a minute and try again.")
    hits.append(now)


@app.get("/health")
def health():
    try:
        load_artifacts()
        ml_status = "ready"
    except Exception as exc:
        logger.warning("ML model unavailable: %s", exc)
        ml_status = "unavailable"
    return {
        "status": "ok",
        "ml": ml_status,
        "iot": "enabled" if os.getenv("ARECASMART_IOT_API_TOKEN", "").strip() else "unconfigured",
    }


@app.get("/api/v1/weather")
def get_weather(
    state: str = Query("Karnataka", min_length=2),
    district: str = Query("", max_length=120),
    taluk: str = Query("", max_length=120),
    village: str = Query("", max_length=120),
    location: str = Query("", max_length=300),
    lat: float | None = Query(None, ge=-90, le=90),
    lon: float | None = Query(None, ge=-180, le=180),
):
    try:
        return weather_service.get_weather(
            state=state, district=district, taluk=taluk, village=village,
            location=location, lat=lat, lon=lon,
        )
    except WeatherServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.post("/api/v1/sensors/readings", dependencies=[Depends(_require_device_token)])
def ingest_sensor_reading(payload: SensorReadingIn):
    """Receive telemetry, validate it, and recalculate the safe pump command."""
    try:
        return irrigation_service.record_reading(payload.model_dump())
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=400, detail="Invalid sensor reading timestamp or payload.") from exc


@app.get("/api/v1/devices/{device_id}/command", dependencies=[__import__("fastapi").Depends(_require_device_token)])
def get_device_command(device_id: str = Path(min_length=1, max_length=80, pattern=r"^[A-Za-z0-9._:-]+$")):
    """ESP32 polling endpoint: reports auto/manual target and safety stop state."""
    return irrigation_service.get_command(device_id)


@app.post("/api/v1/devices/{device_id}/control", dependencies=[__import__("fastapi").Depends(_require_device_token)])
def set_device_control(
    payload: DeviceControlIn,
    device_id: str = __import__("fastapi").Path(min_length=1, max_length=80, pattern=r"^[A-Za-z0-9._:-]+$"),
):
    """Request auto/manual mode or manual pump operation; safety gates remain active."""
    return irrigation_service.set_control(device_id, mode=payload.mode, pump_on=payload.pump_on)


@app.post("/api/v1/devices/{device_id}/emergency-stop", dependencies=[__import__("fastapi").Depends(_require_device_token)])
def set_device_emergency_stop(
    payload: EmergencyStopIn,
    device_id: str = __import__("fastapi").Path(min_length=1, max_length=80, pattern=r"^[A-Za-z0-9._:-]+$"),
):
    """Activate or clear the emergency stop. Clearing it never directly starts the pump."""
    return irrigation_service.set_emergency_stop(device_id, payload.active)


@app.patch("/api/v1/devices/{device_id}/settings", dependencies=[__import__("fastapi").Depends(_require_device_token)])
def update_device_settings(
    payload: IrrigationSettingsIn,
    device_id: str = __import__("fastapi").Path(min_length=1, max_length=80, pattern=r"^[A-Za-z0-9._:-]+$"),
):
    """Update safety/threshold settings. Defaults are demo values, not agronomic advice."""
    return irrigation_service.update_settings(device_id, payload.model_dump(exclude_unset=True))


@app.get("/api/v1/devices/{device_id}/readings", dependencies=[__import__("fastapi").Depends(_require_device_token)])
def get_device_reading_history(
    device_id: str = __import__("fastapi").Path(min_length=1, max_length=80, pattern=r"^[A-Za-z0-9._:-]+$"),
    limit: int = Query(100, ge=1, le=500),
):
    """Return bounded recent telemetry for the dashboard/history integration."""
    return irrigation_service.get_history(device_id, limit)


@app.get("/api/v1/devices/{device_id}/status", dependencies=[__import__("fastapi").Depends(_require_device_token)])
def get_device_status(device_id: str = __import__("fastapi").Path(min_length=1, max_length=80, pattern=r"^[A-Za-z0-9._:-]+$")):
    return irrigation_service.get_status(device_id)


@app.post("/api/v1/predict")
async def run_feature_prediction(payload: dict):
    return {
        "detail": "Feature prediction endpoint is available for simulated sensor data. Use /api/v1/predict/image for trained image disease prediction.",
        "received_features": payload.get("features", {}),
    }


@app.post("/api/v1/predict/image")
async def run_image_prediction(request: Request, file: UploadFile = File(...)):
    _check_rate_limit(request)
    allowed = {".jpg", ".jpeg", ".png", ".webp"}
    filename = file.filename or ""
    extension = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if extension not in allowed:
        raise HTTPException(status_code=400, detail="Please upload a JPG, JPEG, PNG, or WEBP image.")
    max_bytes = 10 * 1024 * 1024
    image_bytes = await file.read(max_bytes + 1)
    if not image_bytes:
        raise HTTPException(status_code=400, detail="The uploaded image is empty.")
    if len(image_bytes) > max_bytes:
        raise HTTPException(status_code=413, detail="Image is too large. Please upload an image smaller than 10 MB.")
    try:
        result = predict_image(image_bytes, filename)
        result["predicted_at"] = datetime.now(timezone.utc).isoformat()
        result["image_reference"] = {"filename": filename, "kind": "client_upload_reference", "stored": False}
        result["guidance"] = care_guidance(result["prediction"])
        return result
    except ModelNotLoadedError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        logger.exception("ML prediction failed for %s", filename)
        raise HTTPException(status_code=500, detail=str(exc)) from exc
