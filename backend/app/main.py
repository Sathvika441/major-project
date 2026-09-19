from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from ml.inference import ModelNotLoadedError, predict

app = FastAPI(title="Major Project Backend", version="1.0.0")


class PredictionRequest(BaseModel):
    features: dict[str, Any] = {}


@app.get("/health")
def health():
    return {"status": "ok", "ml": "placeholder"}


@app.post("/api/v1/predict")
def run_prediction(payload: PredictionRequest):
    try:
        return predict(payload.features)
    except ModelNotLoadedError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
