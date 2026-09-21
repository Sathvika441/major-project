"""Placeholder inference interface.

The trained ML model is not integrated yet. Keep this module as the stable
backend interface so the API can start and the real model can be plugged in
later without changing the API route.
"""


class ModelNotLoadedError(RuntimeError):
    """Raised when prediction is requested before a trained model is loaded."""


def predict(features: dict) -> dict:
    """Placeholder prediction entry point.

    The real trained model will replace this implementation later.
    """
    raise ModelNotLoadedError(
        "ML model is not integrated yet. Prediction is currently unavailable."
    )
