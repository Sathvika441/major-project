from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from ml.inference import ModelNotLoadedError, predict_image


app = FastAPI(title="Major Project Backend", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    try:
        from ml.inference import _load_artifacts

        _load_artifacts()
        ml_status = "ready"
    except Exception:
        ml_status = "unavailable"

    return {"status": "ok", "ml": ml_status}


@app.post("/api/v1/predict")
async def run_feature_prediction(payload: dict):
    return {
        "detail": "Feature prediction endpoint is available for simulated sensor data. Use /api/v1/predict/image for trained image disease prediction.",
        "received_features": payload.get("features", {}),
    }


@app.post("/api/v1/predict/image")
async def run_image_prediction(file: UploadFile = File(...)):
    allowed_extensions = {".jpg", ".jpeg", ".png", ".webp"}
    filename = file.filename or ""
    extension = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    if extension not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail="Please upload a JPG, JPEG, PNG, or WEBP image.",
        )

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="The uploaded image is empty.")

    try:
        return predict_image(image_bytes, filename)
    except ModelNotLoadedError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
