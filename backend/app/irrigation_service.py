"""In-memory IoT telemetry and fail-safe irrigation command state.

This is an exhibition/prototype store. Data is intentionally bounded in memory and
is lost on process restart; production persistence belongs in Firestore or another
durable store.
"""
from __future__ import annotations

from collections import deque
from copy import deepcopy
from datetime import datetime, timezone
from threading import RLock
from typing import Any


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def as_utc(value: datetime | str | None) -> datetime:
    if value is None:
        return utc_now()
    if isinstance(value, str):
        value = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


class IrrigationService:
    """Own per-device sensor history, settings and safe pump-command state."""

    HISTORY_LIMIT = 500
    EVENT_LIMIT = 200

    def __init__(self) -> None:
        self._lock = RLock()
        self._devices: dict[str, dict[str, Any]] = {}

    def _device(self, device_id: str) -> dict[str, Any]:
        if device_id not in self._devices:
            now = utc_now()
            self._devices[device_id] = {
                "device_id": device_id,
                "farm_id": None,
                "readings": deque(maxlen=self.HISTORY_LIMIT),
                "events": deque(maxlen=self.EVENT_LIMIT),
                "settings": {
                    # Exhibition defaults only; validate field thresholds for the
                    # actual crop, soil, sensor, root zone and installation.
                    "crop": "arecanut",
                    "start_moisture_percent": 30.0,
                    "stop_moisture_percent": 45.0,
                    "minimum_interval_minutes": 30,
                    "maximum_run_seconds": 30,
                    "maximum_reading_age_seconds": 60,
                    "automatic_enabled": True,
                },
                "command": {
                    "mode": "auto",
                    "pump_on": False,
                    "emergency_stop": False,
                    "reason": "Pump is off until a valid fresh sensor reading is received.",
                    "updated_at": now,
                },
                "manual_pump_request": False,
                "output_pump_on": False,
                "pump_started_at": None,
                "last_run_completed_at": None,
            }
        return self._devices[device_id]

    @staticmethod
    def _event(device: dict[str, Any], event: str, reason: str) -> None:
        device["events"].append({"event": event, "reason": reason, "at": utc_now()})

    def record_reading(self, payload: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            device = self._device(payload["device_id"])
            device["farm_id"] = payload.get("farm_id") or device["farm_id"]
            reading = deepcopy(payload)
            reading["observed_at"] = as_utc(reading.get("observed_at"))
            reading["received_at"] = utc_now()
            device["readings"].append(reading)
            self._event(device, "reading_received", "Sensor reading received.")
            self._evaluate(device)
            return self._public_status(device)

    def get_command(self, device_id: str) -> dict[str, Any]:
        with self._lock:
            device = self._device(device_id)
            self._evaluate(device)
            command = deepcopy(device["command"])
            command["device_id"] = device_id
            return command

    def set_control(
        self,
        device_id: str,
        *,
        mode: str | None = None,
        pump_on: bool | None = None,
    ) -> dict[str, Any]:
        with self._lock:
            device = self._device(device_id)
            command = device["command"]
            if mode is not None and mode != command["mode"]:
                command["mode"] = mode
                self._event(device, "mode_changed", f"Irrigation mode set to {mode}.")
                # A mode change must not accidentally preserve an earlier manual ON.
                device["manual_pump_request"] = False
            if command["mode"] == "manual" and pump_on is not None:
                device["manual_pump_request"] = pump_on
                self._event(
                    device,
                    "manual_pump_requested",
                    "Manual pump ON requested." if pump_on else "Manual pump OFF requested.",
                )
            command["updated_at"] = utc_now()
            self._evaluate(device)
            return self._public_status(device)

    def set_emergency_stop(self, device_id: str, active: bool) -> dict[str, Any]:
        with self._lock:
            device = self._device(device_id)
            command = device["command"]
            was_active = command["emergency_stop"]
            command["emergency_stop"] = active
            command["updated_at"] = utc_now()
            if active:
                device["manual_pump_request"] = False
                self._event(device, "emergency_stop_activated", "Emergency stop activated; pump forced OFF.")
            elif was_active:
                device["manual_pump_request"] = False
                self._event(
                    device,
                    "emergency_stop_cleared",
                    "Emergency stop cleared; pump remains OFF until control logic permits operation.",
                )
            self._evaluate(device)
            return self._public_status(device)

    def update_settings(self, device_id: str, settings: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            device = self._device(device_id)
            device["settings"].update(settings)
            self._event(device, "settings_updated", "Irrigation safety settings updated.")
            self._evaluate(device)
            return self._public_status(device)

    def get_history(self, device_id: str, limit: int = 100) -> dict[str, Any]:
        with self._lock:
            device = self._device(device_id)
            rows = list(device["readings"])[-limit:]
            return {
                "device_id": device_id,
                "count": len(rows),
                "readings": deepcopy(rows),
                "storage": "in_memory",
            }

    def get_status(self, device_id: str) -> dict[str, Any]:
        with self._lock:
            device = self._device(device_id)
            self._evaluate(device)
            return self._public_status(device)

    def _evaluate(self, device: dict[str, Any]) -> None:
        command = device["command"]
        settings = device["settings"]
        now = utc_now()
        previous_pump_on = bool(device["output_pump_on"])
        latest = device["readings"][-1] if device["readings"] else None

        if command["emergency_stop"]:
            should_run, reason = False, "Emergency stop is active."
        elif not settings["automatic_enabled"] and command["mode"] == "auto":
            should_run, reason = False, "Automatic irrigation is disabled in device settings."
        elif latest is None:
            should_run, reason = False, "Pump blocked: no sensor reading received."
        elif not latest.get("sensor_valid", True):
            should_run, reason = False, "Pump blocked: sensor reading is marked invalid."
        elif (now - latest["observed_at"]).total_seconds() > settings["maximum_reading_age_seconds"]:
            should_run, reason = False, "Pump blocked: sensor reading is stale."
        elif (latest["observed_at"] - now).total_seconds() > 60:
            should_run, reason = False, "Pump blocked: sensor timestamp is in the future."
        elif command["mode"] == "manual":
            should_run = bool(device["manual_pump_request"])
            reason = "Manual pump control." if should_run else "Pump switched OFF by manual control."
        else:
            moisture = latest.get("soil_moisture_percent")
            if moisture is None:
                should_run, reason = False, "Pump blocked: soil-moisture value is missing."
            elif previous_pump_on and moisture < settings["stop_moisture_percent"]:
                should_run, reason = True, "Automatic irrigation continues until the stop-moisture threshold is reached."
            elif moisture <= settings["start_moisture_percent"]:
                last_stop = device["last_run_completed_at"]
                interval_seconds = settings["minimum_interval_minutes"] * 60
                if last_stop is None or (now - last_stop).total_seconds() >= interval_seconds:
                    should_run, reason = True, "Automatic irrigation started: soil moisture is at or below the configured start threshold."
                else:
                    should_run, reason = False, "Pump blocked: minimum interval between irrigation runs has not elapsed."
            else:
                should_run, reason = False, "Soil moisture is above the automatic start threshold."

        started_at = device["pump_started_at"]
        if should_run and previous_pump_on and started_at is not None:
            elapsed = (now - started_at).total_seconds()
            if elapsed >= settings["maximum_run_seconds"]:
                should_run = False
                reason = "Pump stopped by maximum continuous-run safety limit."

        if should_run and not previous_pump_on:
            device["pump_started_at"] = now
            self._event(device, "pump_started", reason)
        elif not should_run and previous_pump_on:
            device["last_run_completed_at"] = now
            device["pump_started_at"] = None
            self._event(device, "pump_stopped", reason)
        elif not should_run:
            device["pump_started_at"] = None

        device["output_pump_on"] = should_run
        command["pump_on"] = should_run
        command["reason"] = reason
        command["updated_at"] = now

    def _public_status(self, device: dict[str, Any]) -> dict[str, Any]:
        latest = deepcopy(device["readings"][-1]) if device["readings"] else None
        return {
            "device_id": device["device_id"],
            "farm_id": device["farm_id"],
            "latest_reading": latest,
            "command": deepcopy(device["command"]),
            "settings": deepcopy(device["settings"]),
            "recent_events": deepcopy(list(device["events"])[-20:]),
            "storage": "in_memory",
        }
