"""Adapter boundary for the trained ML model."""

class ModelNotLoadedError(RuntimeError):
    pass


def predict(payload: dict) -> dict:
    raise ModelNotLoadedError("Trained model artifact has not been attached yet")
