"""Tests for safe image validation and prediction output."""
import io
import unittest
from unittest.mock import Mock, patch

import numpy as np
from PIL import Image

from backend.app.ml_service import predict_image


def image_bytes(image_format="PNG", size=(16, 16)):
    buffer = io.BytesIO()
    Image.new("RGB", size, color=(20, 120, 40)).save(buffer, format=image_format)
    return buffer.getvalue()


class MlServiceTests(unittest.TestCase):
    def test_rejects_non_image_before_loading_model(self):
        with patch("backend.app.ml_service.load_artifacts") as load:
            with self.assertRaisesRegex(ValueError, "supported, valid image"):
                predict_image(b"not an image", "leaf.png")
            load.assert_not_called()

    def test_rejects_unsupported_actual_format_before_loading_model(self):
        with patch("backend.app.ml_service.load_artifacts") as load:
            with self.assertRaisesRegex(ValueError, "supported, valid image"):
                predict_image(image_bytes("GIF"), "leaf.png")
            load.assert_not_called()

    def test_predicts_valid_image_and_returns_ranked_classes(self):
        model = Mock()
        model.predict.return_value = np.array([[0.15, 0.85]], dtype=np.float32)
        with patch(
            "backend.app.ml_service.load_artifacts",
            return_value=(model, ["Healthy_Leaf", "Mahali_Koleroga"]),
        ):
            result = predict_image(image_bytes(), "leaf.png")

        self.assertEqual(result["prediction"], "Mahali_Koleroga")
        self.assertAlmostEqual(result["confidence"], 0.85, places=5)
        self.assertEqual(result["predictions"][0]["class_name"], "Mahali_Koleroga")
        model.predict.assert_called_once()


if __name__ == "__main__":
    unittest.main()
