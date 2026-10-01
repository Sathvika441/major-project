import logging
import time
from collections import defaultdict, deque
from fastapi import FastAPI, File, HTTPException, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from .ml_service import ModelNotLoadedError, load_artifacts, predict_image
from .weather_service import OpenMeteoWeatherService, WeatherServiceError

logger=logging.getLogger(__name__)
weather_service=OpenMeteoWeatherService()
app=FastAPI(title="Major Project Backend",version="2.1.0")
app.add_middleware(CORSMiddleware,allow_origins=["*"],allow_credentials=False,allow_methods=["*"],allow_headers=["*"])

_PREDICT_WINDOW_SECONDS=60
_PREDICT_MAX_REQUESTS=12
_predict_hits=defaultdict(deque)

def _check_rate_limit(request: Request):
    now=time.monotonic(); key=request.client.host if request.client else "unknown"; hits=_predict_hits[key]
    while hits and now-hits[0]>_PREDICT_WINDOW_SECONDS: hits.popleft()
    if len(hits)>=_PREDICT_MAX_REQUESTS: raise HTTPException(status_code=429,detail="Too many image predictions. Please wait a minute and try again.")
    hits.append(now)

@app.get("/health")
def health():
    try: load_artifacts(); ml_status="ready"
    except Exception as exc: logger.warning("ML model unavailable: %s",exc); ml_status="unavailable"
    return {"status":"ok","ml":ml_status}

@app.get("/api/v1/weather")
def get_weather(state:str=Query("Karnataka",min_length=2),district:str=Query("",max_length=120),taluk:str=Query("",max_length=120),village:str=Query("",max_length=120),location:str=Query("",max_length=300),lat:float|None=Query(None,ge=-90,le=90),lon:float|None=Query(None,ge=-180,le=180)):
    try: return weather_service.get_weather(state=state,district=district,taluk=taluk,village=village,location=location,lat=lat,lon=lon)
    except WeatherServiceError as exc: raise HTTPException(status_code=502,detail=str(exc)) from exc

@app.post("/api/v1/predict")
async def run_feature_prediction(payload:dict):
    return {"detail":"Feature prediction endpoint is available for simulated sensor data. Use /api/v1/predict/image for trained image disease prediction.","received_features":payload.get("features",{})}

@app.post("/api/v1/predict/image")
async def run_image_prediction(request:Request,file:UploadFile=File(...)):
    _check_rate_limit(request)
    allowed={".jpg",".jpeg",".png",".webp"}; filename=file.filename or ""
    extension="."+filename.rsplit(".",1)[-1].lower() if "." in filename else ""
    if extension not in allowed: raise HTTPException(status_code=400,detail="Please upload a JPG, JPEG, PNG, or WEBP image.")
    max_bytes=10*1024*1024; image_bytes=await file.read(max_bytes+1)
    if not image_bytes: raise HTTPException(status_code=400,detail="The uploaded image is empty.")
    if len(image_bytes)>max_bytes: raise HTTPException(status_code=413,detail="Image is too large. Please upload an image smaller than 10 MB.")
    try: return predict_image(image_bytes,filename)
    except ModelNotLoadedError as exc: raise HTTPException(status_code=503,detail=str(exc)) from exc
    except ValueError as exc: raise HTTPException(status_code=400,detail=str(exc)) from exc
    except RuntimeError as exc: logger.exception("ML prediction failed for %s",filename); raise HTTPException(status_code=500,detail=str(exc)) from exc
