import unittest
from backend.app.weather_service import OpenMeteoWeatherService

class GuidanceTests(unittest.TestCase):
    def test_clear_conditions_are_suitable(self):
        g=OpenMeteoWeatherService._guidance(10,0,8,60,0)
        self.assertEqual(g["spraying"],"Suitable")
        self.assertEqual(g["drying"],"Suitable")
        self.assertEqual(g["transport"],"Suitable")

    def test_thunderstorm_avoids_field_operations(self):
        g=OpenMeteoWeatherService._guidance(20,0,8,70,95)
        self.assertEqual(g["spraying"],"Avoid")
        self.assertEqual(g["drying"],"Avoid")
        self.assertEqual(g["transport"],"Avoid")
        self.assertEqual(g["status_line"],"Thunderstorm risk")

    def test_rain_can_remove_irrigation_need(self):
        g=OpenMeteoWeatherService._guidance(80,5,8,70,61)
        self.assertEqual(g["irrigation"],"Not required")

if __name__=="__main__":
    unittest.main()
