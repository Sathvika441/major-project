import unittest
from unittest.mock import patch
from backend.app.weather_service import OpenMeteoWeatherService

class GuidanceTests(unittest.TestCase):
    def test_clear_conditions_are_suitable(self):
        g=OpenMeteoWeatherService._guidance(10,0,8,60,0,10)
        self.assertEqual(g["spraying"],"Suitable")
        self.assertEqual(g["drying"],"Suitable")
        self.assertEqual(g["transport"],"Suitable")

    def test_thunderstorm_avoids_field_operations(self):
        g=OpenMeteoWeatherService._guidance(20,0,8,70,95,10)
        self.assertEqual(g["spraying"],"Avoid")
        self.assertEqual(g["drying"],"Avoid")
        self.assertEqual(g["transport"],"Avoid")
        self.assertEqual(g["status_line"],"Thunderstorm risk")

    def test_outside_field_hours_is_not_suitable(self):
        g=OpenMeteoWeatherService._guidance(10,0,8,60,0,20)
        self.assertEqual(g["spraying"],"Not suitable")
        self.assertEqual(g["status_line"],"Outside preferred field-work hours")

    def test_rain_can_remove_irrigation_need(self):
        g=OpenMeteoWeatherService._guidance(80,5,8,70,61,10)
        self.assertEqual(g["irrigation"],"Not required")

    def test_reverse_geocode_prefers_village_and_reports_district(self):
        service = OpenMeteoWeatherService()
        with patch.object(
            OpenMeteoWeatherService,
            "_get_json",
            return_value={"address": {"village": "Example Village", "state_district": "Mysuru"}},
        ):
            self.assertEqual(
                service._reverse_geocode(12.3, 76.6),
                {"locality": "Example Village", "district": "Mysuru"},
            )

    def test_reverse_geocode_falls_back_to_city_when_district_missing(self):
        service = OpenMeteoWeatherService()
        with unittest.mock.patch.object(
            OpenMeteoWeatherService,
            "_get_json",
            return_value={"address": {"city": "Mysuru"}},
        ):
            self.assertEqual(
                service._reverse_geocode(12.3, 76.6),
                {"locality": "", "district": "Mysuru"},
            )

if __name__=="__main__":
    unittest.main()
