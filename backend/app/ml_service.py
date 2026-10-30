"""ML inference service for arecanut disease detection."""

from functools import lru_cache
import io
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image, UnidentifiedImageError
from tensorflow.keras.preprocessing import image


BASE_DIR = Path(__file__).resolve().parents[2]
ML_MODEL_DIR = BASE_DIR / "ML model"

MODEL_PATH = ML_MODEL_DIR / "models" / "arecanut_model.keras"
CLASS_NAMES_PATH = ML_MODEL_DIR / "models" / "class_names.json"

IMG_SIZE = (224, 224)
MAX_IMAGE_PIXELS = 20_000_000


class ModelNotLoadedError(RuntimeError):
    """Raised when the trained ML model cannot be loaded."""


@lru_cache(maxsize=1)
def load_artifacts():
    """Load the trained model and class names once."""

    if not MODEL_PATH.exists():
        raise ModelNotLoadedError(
            f"ML model not found at: {MODEL_PATH}"
        )

    if not CLASS_NAMES_PATH.exists():
        raise ModelNotLoadedError(
            f"Class names file not found at: {CLASS_NAMES_PATH}"
        )

    try:
        model = tf.keras.models.load_model(MODEL_PATH)
        class_names = json.loads(
            CLASS_NAMES_PATH.read_text(encoding="utf-8")
        )
    except Exception as exc:
        raise ModelNotLoadedError(
            "Failed to load the trained arecanut ML model."
        ) from exc

    if not isinstance(class_names, list) or not class_names:
        raise ModelNotLoadedError(
            "class_names.json does not contain a valid class list."
        )

    if model.output_shape[-1] != len(class_names):
        raise ModelNotLoadedError(
            "Model output classes do not match class_names.json."
        )

    return model, [str(name) for name in class_names]


def predict_image(
    image_bytes: bytes,
    filename: str | None = None,
) -> dict:
    """Run disease prediction on an uploaded image."""

    # Validate the actual image content and dimensions before loading the ML
    # model or decoding a potentially huge compressed image into memory.
    try:
        with Image.open(io.BytesIO(image_bytes)) as source:
            if source.format not in {"JPEG", "PNG", "WEBP"}:
                raise ValueError("Unsupported image format.")
            width, height = source.size
            if width <= 0 or height <= 0 or width * height > MAX_IMAGE_PIXELS:
                raise ValueError("Image dimensions are too large. Please upload an image with at most 20 megapixels.")
            source.verify()

        img = image.load_img(
            io.BytesIO(image_bytes),
            target_size=IMG_SIZE,
            color_mode="rgb",
        )
    except (Image.DecompressionBombError, UnidentifiedImageError, OSError, ValueError) as exc:
        raise ValueError(
            "The uploaded file is not a supported, valid image or its dimensions are too large."
        ) from exc

    model, class_names = load_artifacts()

    try:
        img_array = image.img_to_array(img)
        img_array = np.expand_dims(img_array, axis=0)

        # MobileNetV2 preprocessing is already part of the trained model.
        predictions = model.predict(img_array, verbose=0)[0]
    except Exception as exc:
        raise RuntimeError(
            "The trained ML model failed during prediction."
        ) from exc

    predicted_index = int(np.argmax(predictions))

    ranked_predictions = [
        {
            "class_name": class_names[index],
            "confidence": float(predictions[index]),
        }
        for index in np.argsort(predictions)[::-1]
    ]

    return {
        "filename": filename,
        "prediction": class_names[predicted_index],
        "confidence": float(predictions[predicted_index]),
        "predictions": ranked_predictions,
        "model": MODEL_PATH.name,
    }
