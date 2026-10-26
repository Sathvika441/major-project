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


def _device_docs(db, device_id: str):
    """Find registered Flutter device records by their physical device ID."""
    return list(
        db.collection_group("devices")
        .where(filter=FieldFilter("deviceId", "==", device_id))
        .stream()
    )


def owns_device(uid: str, device_id: str) -> bool:
    """Allow access only when exactly one active device record belongs to uid."""
    db = _client()
    if db is None:
        return False
    docs = _device_docs(db, device_id)
    if len(docs) != 1:
        return False
    doc = docs[0]
    data = doc.to_dict() or {}
    return (
        doc.reference.path == f"users/{uid}/devices/{doc.id}"
        and data.get("userId") == uid
        and data.get("isActive", True) is True
    )

def save_reading(reading: dict[str, Any], status: dict[str, Any] | None = None) -> None:
    """Persist telemetry and mirror it to the single registered device record.

    Canonical relationships:
    - users/{uid}/farms/{farmId}: farm profile
    - users/{uid}/devices/{documentId}: user-owned registered device
    - iot_devices/{deviceId}: backend device snapshot and farm link
    - iot_devices/{deviceId}/readings/{readingId}: durable telemetry history

    Telemetry is still accepted for devices without an app registration, but
    it is not attached to a user/farm record unless exactly one record matches.
    """
    db = _client()
    if db is None:
        return

    device_id = str(reading["device_id"])
    root = db.collection("iot_devices").document(device_id)
    observed_at = reading.get("observed_at")
    received_at = reading.get("received_at") or datetime.now(timezone.utc)
    data = dict(reading)
    data["device_id"] = device_id
    data["observed_at"] = _as_datetime(observed_at)
    data["received_at"] = _as_datetime(received_at)
    data["updatedAt"] = firestore.SERVER_TIMESTAMP

    docs = _device_docs(db, device_id)
    device_ref = docs[0].reference if len(docs) == 1 else None
    registered = (docs[0].to_dict() or {}) if device_ref is not None else {}
    # An inactive or incomplete registration must not receive telemetry links.
    if device_ref is not None and (
        registered.get("isActive", True) is not True
        or not registered.get("userId")
        or not registered.get("farmId")
    ):
        device_ref = None
        registered = {}
    registered_uid = registered.get("userId")
    registered_farm_id = registered.get("farmId")
    telemetry_farm_id = reading.get("farm_id")

    # Resolve the registered farm under the same owner. Do not write a farm
    # link if the user/farm relationship is inconsistent or no longer active.
    if device_ref is not None:
        valid_farm = False
        if registered_uid and registered_farm_id:
            farm_snapshot = (
                db.collection("users")
                .document(str(registered_uid))
                .collection("farms")
                .document(str(registered_farm_id))
                .get()
            )
            farm_data = farm_snapshot.to_dict() or {}
            valid_farm = farm_snapshot.exists and farm_data.get("isActive", True) is True
        if not valid_farm:
            registered_farm_id = None

    # Keep the user-owned registration as the source of truth for user/farm
    # relationships. Only fall back to telemetry farm_id for unregistered
    # prototype sensors.
    farm_id = registered_farm_id if device_ref is not None else telemetry_farm_id
    data["farm_id"] = farm_id
    root_payload = {
        "deviceId": device_id,
        "updatedAt": firestore.SERVER_TIMESTAMP,
        "latestReading": data,
    }
    # Do not erase existing ownership fields when a device has no unique,
    # valid registration (for example during initial hardware provisioning).
    if device_ref is not None and registered_uid:
        root_payload["userId"] = registered_uid
    if farm_id:
        root_payload["farmId"] = farm_id
    if status is not None:
        root_payload["status"] = _clean(status)
    root.set(root_payload, merge=True)
    root.collection("readings").document().set(data)

    # DeviceModel consumes camelCase reading fields with an ISO timestamp.
    app_reading = {
        "soilMoisture": reading.get("soil_moisture_percent"),
        "temperature": reading.get("temperature_c"),
        "humidity": reading.get("humidity_percent"),
        "rainfall": reading.get("rainfall_mm"),
        "timestamp": (_as_datetime(observed_at) or received_at).isoformat()
        if isinstance((_as_datetime(observed_at) or received_at), datetime)
        else str(_as_datetime(observed_at) or received_at),
    }

    # Avoid assigning readings to multiple users if data contains duplicate IDs.
    if device_ref is not None:
        patch = {
            "latestReading": app_reading,
            "lastSeen": _as_datetime(received_at).isoformat()
            if isinstance(_as_datetime(received_at), datetime)
            else str(_as_datetime(received_at)),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        if farm_id:
            patch["farmId"] = farm_id
        device_ref.set(patch, merge=True)

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
