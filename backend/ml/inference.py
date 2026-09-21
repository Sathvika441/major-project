"""TensorFlow inference service for the trained arecanut disease model."""

from functools import lru_cache
import io
import json
from pathlib import Path

from PIL import UnidentifiedImageError

import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing import image


BASE_DIR = Path(__file__).resolve().parents[2]
MODEL_PATH = BASE_DIR / "ML model" / "models" / "arecanut_model.keras"
CLASS_NAMES_PATH = BASE_DIR / "ML model" / "models" / "class_names.json"
IMG_SIZE = (224, 224)


class ModelNotLoadedError(RuntimeError):
    """Raised when the trained model or class metadata is unavailable."""


@lru_cache(maxsize=1)
def _load_artifacts():
    if not MODEL_PATH.exists():
        raise ModelNotLoadedError(f"ML model not found at {MODEL_PATH}.")
    if not CLASS_NAMES_PATH.exists():
        raise ModelNotLoadedError(f"Class names not found at {CLASS_NAMES_PATH}.")

    try:
        model = tf.keras.models.load_model(MODEL_PATH)
        class_names = json.loads(CLASS_NAMES_PATH.read_text(encoding="utf-8"))
    except Exception as exc:
        raise ModelNotLoadedError("Failed to load the trained ML model.") from exc

    if not isinstance(class_names, list) or not class_names:
        raise ModelNotLoadedError("The model class-name metadata is invalid.")

    return model, [str(name) for name in class_names]


def predict_image(image_bytes: bytes, filename: str | None = None) -> dict:
    model, class_names = _load_artifacts()

    try:
        img = image.load_img(
            io.BytesIO(image_bytes),
            target_size=IMG_SIZE,
            color_mode="rgb",
        )
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise ValueError(
            "The uploaded file could not be decoded as a valid JPG, JPEG, PNG, or WEBP image."
        ) from exc

    try:
        img_array = image.img_to_array(img)
        img_array = np.expand_dims(img_array, axis=0)
        img_array = tf.keras.applications.mobilenet_v2.preprocess_input(
            img_array
        )
        predictions = model.predict(img_array, verbose=0)[0]
    except Exception as exc:
        raise RuntimeError(
            "The image was read successfully, but the trained ML model failed during prediction."
        ) from exc

    if len(predictions) != len(class_names):
        raise ModelNotLoadedError(
            "Model output classes do not match class-name metadata."
        )

    predicted_index = int(np.argmax(predictions))
    ranked = [
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
        "predictions": ranked,
        "model": MODEL_PATH.name,
    }
