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
                self.assertTrue(result["pesticide"])
                self.assertIn("pesticide_status", result)
                self.assertIn("safety_note", result)
                self.assertIn("checked_at", result)
                self.assertNotIn("fertilizer", result)

    def test_only_verified_koleroga_recommendation_has_a_dose(self):
        result = care_guidance("Mahali_Koleroga")
        self.assertIn("3 g product/L", result["pesticide"])
        self.assertIn("1% Bordeaux mixture", result["pesticide"])

    def test_no_unverified_doses_are_returned(self):
        for label in [
            "Stem_bleeding", "bud borer", "stem cracking",
            "yellow leaf disease", "Healthy_Leaf",
        ]:
            with self.subTest(label=label):
                result = care_guidance(label)
                self.assertIn("No ", result["pesticide"])
                self.assertNotIn("ml/L", result["pesticide"])
                self.assertNotIn("g/L", result["pesticide"])

    def test_yellow_leaf_disease_does_not_claim_a_cure(self):
        result = care_guidance("yellow leaf disease")
        self.assertIn("No curative pesticide", result["pesticide"])

    def test_unknown_label_is_safe(self):
        result = care_guidance("unknown disease")
        self.assertIn("No pesticide", result["pesticide"])
        self.assertIn("Seek local", result["actions"][1])


if __name__ == "__main__":
    unittest.main()
