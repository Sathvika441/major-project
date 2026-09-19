from fastapi import FastAPI, HTTPException

from ml.inference import ModelNotLoadedError, predict

app = FastAPI(title="Major Project Backend", version="1.0.0")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/api/v1/predict")
def run_prediction(payload: dict):
    try:
        return predict(payload)
    except ModelNotLoadedError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
