import unittest

from app.disease_guidance import care_guidance


class DiseaseGuidanceTests(unittest.TestCase):
    def test_guidance_exists_for_all_model_classes(self):
        labels = [
            "Healthy_Leaf", "Healthy_Nut", "Healthy_Trunk",
            "Mahali_Koleroga", "Stem_bleeding", "bud borer",
            "healthy_foot", "stem cracking", "yellow leaf disease",
        ]
        for label in labels:
            with self.subTest(label=label):
                result = care_guidance(label)
                self.assertEqual(result["class_name"], label)
                self.assertTrue(result["actions"])
                self.assertTrue(result["fertilizer"])
                self.assertIn("safety_note", result)
                self.assertIn("checked_at", result)

    def test_disease_advice_does_not_treat_fertilizer_as_a_cure(self):
        for label in [
            "Mahali_Koleroga", "Stem_bleeding", "bud borer",
            "stem cracking", "yellow leaf disease",
        ]:
            with self.subTest(label=label):
                result = care_guidance(label)
                self.assertIn("not", result["fertilizer"].lower())

    def test_unknown_label_is_safe(self):
        result = care_guidance("unknown disease")
        self.assertIn("No fertilizer", result["fertilizer"])
        self.assertIn("Seek local", result["actions"][1])


if __name__ == "__main__":
    unittest.main()
