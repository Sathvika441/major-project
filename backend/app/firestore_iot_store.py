"""Optional Firestore persistence and Firebase ID-token verification for IoT APIs.

Configure Application Default Credentials (for example GOOGLE_APPLICATION_CREDENTIALS
pointing to a service-account JSON kept outside the repository) and FIREBASE_PROJECT_ID.
Never commit service-account credentials.
"""
from __future__ import annotations

import os
from datetime import datetime, timezone
from threading import RLock
from typing import Any

import firebase_admin
from firebase_admin import auth, credentials, firestore
from google.cloud.firestore_v1 import FieldFilter, Query


_lock = RLock()
_app = None
_db = None


def _client():
    global _app, _db
    with _lock:
        if _db is not None:
            return _db
        project_id = os.getenv("FIREBASE_PROJECT_ID", "").strip()
        if not project_id:
            return None
        try:
            _app = firebase_admin.get_app()
        except ValueError:
            credential_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
            credential = credentials.Certificate(credential_path) if credential_path else credentials.ApplicationDefault()
            _app = firebase_admin.initialize_app(credential, {"projectId": project_id})
        _db = firestore.client(_app)
        return _db


def firebase_ready() -> bool:
    try:
        return _client() is not None
    except Exception:
        return False


def verify_bearer_token(authorization: str | None) -> dict[str, Any]:
    if not authorization or not authorization.startswith("Bearer "):
        raise ValueError("Missing Firebase bearer token.")
    token = authorization[7:].strip()
    if not token:
        raise ValueError("Missing Firebase bearer token.")
    claims = auth.verify_id_token(token, app=_app or firebase_admin.get_app())
    return claims


def owns_device(uid: str, device_id: str) -> bool:
    db = _client()
    if db is None:
        return False
    # Device records are already stored by the Flutter app at
    # users/{uid}/devices/{documentId}.
    docs = (
        db.collection("users").document(uid).collection("devices")
        .where(filter=FieldFilter("deviceId", "==", device_id))
        .limit(1)
        .stream()
    )
    return any(True for _ in docs)


def save_reading(reading: dict[str, Any], status: dict[str, Any] | None = None) -> None:
    db = _client()
    if db is None:
        return
    device_id = reading["device_id"]
    root = db.collection("iot_devices").document(device_id)
    observed_at = reading.get("observed_at")
    received_at = reading.get("received_at") or datetime.now(timezone.utc)
    data = dict(reading)
    data["observed_at"] = _as_datetime(observed_at)
    data["received_at"] = _as_datetime(received_at)
    data["updatedAt"] = firestore.SERVER_TIMESTAMP
    root.set({
        "deviceId": device_id,
        "farmId": reading.get("farm_id"),
        "latestReading": data,
        "updatedAt": firestore.SERVER_TIMESTAMP,
        **({"status": _clean(status)} if status is not None else {}),
    }, merge=True)
    root.collection("readings").document().set(data)

    # Keep the app's existing per-user device card in sync with real telemetry.
    # The Flutter DeviceModel expects camelCase keys for latestReading.
    docs = (
        db.collection_group("devices")
        .where(filter=FieldFilter("deviceId", "==", device_id))
        .stream()
    )
    app_reading = {
        "soilMoisture": reading.get("soil_moisture_percent"),
        "temperature": reading.get("temperature_c"),
        "humidity": reading.get("humidity_percent"),
        "rainfall": reading.get("rainfall_mm"),
        "timestamp": _as_datetime(observed_at) or received_at,
    }
    for doc in docs:
        if len(doc.reference.path.split("/")) == 4 and doc.reference.path.startswith("users/"):
            doc.reference.set({
                "latestReading": app_reading,
                "lastSeen": _as_datetime(received_at),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)


def save_status(device_id: str, status: dict[str, Any]) -> None:
    db = _client()
    if db is None:
        return
    db.collection("iot_devices").document(device_id).set({
        "deviceId": device_id,
        "status": _clean(status),
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)


def get_status(device_id: str) -> dict[str, Any] | None:
    db = _client()
    if db is None:
        return None
    snapshot = db.collection("iot_devices").document(device_id).get()
    if not snapshot.exists:
        return None
    data = snapshot.to_dict() or {}
    return _clean(data.get("status")) if data.get("status") else None



def get_latest_reading(device_id: str) -> dict[str, Any] | None:
    db = _client()
    if db is None:
        return None
    snapshot = db.collection("iot_devices").document(device_id).get()
    if not snapshot.exists:
        return None
    data = snapshot.to_dict() or {}
    latest = data.get("latestReading")
    return _clean(latest) if isinstance(latest, dict) else None

def get_history(device_id: str, limit: int = 100) -> dict[str, Any]:
    db = _client()
    if db is None:
        raise RuntimeError("Firestore persistence is not configured.")
    query = (
        db.collection("iot_devices").document(device_id).collection("readings")
        .order_by("received_at", direction=Query.DESCENDING)
        .limit(limit)
    )
    rows = [_clean(doc.to_dict() or {}) for doc in query.stream()]
    rows.reverse()
    return {"device_id": device_id, "count": len(rows), "readings": rows, "storage": "firestore"}


def _as_datetime(value: Any) -> Any:
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return value
    return value


def _clean(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(k): _clean(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_clean(v) for v in value]
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc).isoformat()
    if hasattr(value, "to_datetime"):
        return value.to_datetime().astimezone(timezone.utc).isoformat()
    return value
