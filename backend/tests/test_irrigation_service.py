"""Unit tests for the prototype irrigation safety rules.

Run from the backend directory with: python -m unittest discover -s tests
"""
import unittest
from datetime import timedelta

from app.irrigation_service import IrrigationService, utc_now


class IrrigationServiceTests(unittest.TestCase):
    def setUp(self):
        self.service = IrrigationService()
        self.device_id = "ARECA_SENSOR_TEST"

    def reading(self, moisture, *, valid=True, observed_at=None):
        return self.service.record_reading({
            "device_id": self.device_id,
            "farm_id": "FARM_TEST",
            "soil_moisture_percent": moisture,
            "soil_moisture_raw": 2500,
            "temperature_c": 28.0,
            "humidity_percent": 70.0,
            "rainfall_mm": 0.0,
            "sensor_valid": valid,
            "observed_at": observed_at or utc_now(),
        })

    def test_pump_defaults_off_without_reading(self):
        command = self.service.get_command(self.device_id)
        self.assertFalse(command["pump_on"])
        self.assertIn("no sensor reading", command["reason"].lower())

    def test_automatic_mode_starts_when_below_start_threshold(self):
        result = self.reading(24.0)
        self.assertTrue(result["command"]["pump_on"])

    def test_automatic_hysteresis_stops_above_stop_threshold(self):
        self.reading(24.0)
        held = self.reading(40.0)
        self.assertTrue(held["command"]["pump_on"])
        stopped = self.reading(46.0)
        self.assertFalse(stopped["command"]["pump_on"])

    def test_invalid_sensor_reading_blocks_pump(self):
        self.reading(24.0)
        result = self.reading(20.0, valid=False)
        self.assertFalse(result["command"]["pump_on"])
        self.assertIn("invalid", result["command"]["reason"].lower())

    def test_stale_sensor_reading_blocks_pump(self):
        result = self.reading(20.0, observed_at=utc_now() - timedelta(seconds=120))
        self.assertFalse(result["command"]["pump_on"])
        self.assertIn("stale", result["command"]["reason"].lower())

    def test_manual_control_respects_sensor_safety_and_emergency_stop(self):
        self.reading(50.0)
        requested = self.service.set_control(self.device_id, mode="manual", pump_on=True)
        self.assertTrue(requested["command"]["pump_on"])
        stopped = self.service.set_emergency_stop(self.device_id, True)
        self.assertFalse(stopped["command"]["pump_on"])
        cleared = self.service.set_emergency_stop(self.device_id, False)
        self.assertFalse(cleared["command"]["pump_on"])

    def test_manual_pump_has_maximum_runtime(self):
        self.reading(50.0)
        self.service.update_settings(self.device_id, {"maximum_run_seconds": 5})
        self.service.set_control(self.device_id, mode="manual", pump_on=True)
        # Simulate elapsed runtime without a sleep-based flaky test.
        with self.service._lock:
            self.service._devices[self.device_id]["pump_started_at"] = utc_now() - timedelta(seconds=6)
        command = self.service.get_command(self.device_id)
        self.assertFalse(command["pump_on"])
        self.assertIn("maximum continuous-run", command["reason"].lower())


if __name__ == "__main__":
    unittest.main()
