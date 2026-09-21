from fastapi import FastAPI, File, HTTPException, UploadFile

from ml.inference import ModelNotLoadedError, predict_image


app = FastAPI(title="Major Project Backend", version="2.0.0")


@app.get("/health")
def health():
    try:
        from ml.inference import _load_artifacts

        _load_artifacts()
        ml_status = "ready"
    except Exception:
        ml_status = "unavailable"

    return {"status": "ok", "ml": ml_status}


@app.post("/api/v1/predict/image")
async def run_image_prediction(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Please upload an image file.")

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="The uploaded image is empty.")

    try:
        return predict_image(image_bytes, file.filename)
    except ModelNotLoadedError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
