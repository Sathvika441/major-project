"""Weather and location service backed by Open-Meteo."""
from __future__ import annotations
from datetime import datetime, timedelta, timezone
import json
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search"
FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
CACHE_TTL = timedelta(minutes=15)

SPRAY_MAX_RAIN_PROBABILITY = 35.0
SPRAY_MAX_RAIN_MM = 0.5
SPRAY_MAX_WIND_KMH = 20.0
DRYING_MAX_RAIN_PROBABILITY = 25.0
DRYING_MAX_HUMIDITY = 75.0
DRYING_MAX_WIND_KMH = 30.0
HARVEST_MAX_RAIN_PROBABILITY = 45.0
HARVEST_MAX_WIND_KMH = 35.0
IRRIGATION_RAIN_PROBABILITY = 65.0
IRRIGATION_RAIN_MM = 3.0
THUNDERSTORM_CODES = {95, 96, 97, 98, 99}
FIELD_WORK_START_HOUR = 6
FIELD_WORK_END_HOUR = 18

class WeatherServiceError(RuntimeError):
    pass

class OpenMeteoWeatherService:
    def __init__(self):
        self._cache: dict[str, tuple[datetime, dict]] = {}

    def get_weather(self, *, state="Karnataka", district="", taluk="", village="", location="", lat=None, lon=None):
        if (lat is None) != (lon is None):
            raise WeatherServiceError("Both latitude and longitude are required for coordinate weather requests.")
        key = self._location_key(state,district,taluk,village,location,lat,lon)
        now = datetime.now(timezone.utc)
        cached = self._cache.get(key)
        if cached and now-cached[0] < CACHE_TTL: return cached[1]
        if lat is not None and lon is not None:
            reverse = self._reverse_geocode(float(lat), float(lon)) if location.strip().lower() in {"", "current location"} else {}
            resolved_name = location.strip() or reverse.get("locality") or "Current location"
            resolved={"name":resolved_name,"latitude":float(lat),"longitude":float(lon),"resolved_level":"coordinates","match_score":None}
            resolved_state = state
            resolved_district = district or reverse.get("district", "")
            resolved_locality = reverse.get("locality") or location.strip() or resolved_name
        else:
            if not district and not taluk and not village and not location: district="Shivamogga"
            resolved=self._resolve_location(state=state,district=district,taluk=taluk,village=village,location=location)
            resolved_state,resolved_district,resolved_locality=state,district,resolved["name"]
        forecast=self._fetch_forecast(resolved["latitude"],resolved["longitude"])
        result=self._normalize(forecast=forecast,location=resolved,state=resolved_state,district=resolved_district,taluk=taluk,village=village,locality=resolved_locality)
        self._cache[key]=(now,result)
        return result


    def _reverse_geocode(self, latitude, longitude):
        """Resolve GPS coordinates to a readable locality without blocking weather on geocoder failures."""
        query = urlencode({"lat": latitude, "lon": longitude, "format": "jsonv2", "zoom": 10, "addressdetails": 1})
        try:
            payload = self._get_json(f"https://nominatim.openstreetmap.org/reverse?{query}")
            address = payload.get("address") or {}
            locality = next((address.get(key) for key in ("village", "town", "city", "municipality", "suburb", "hamlet") if address.get(key)), "")
            district = next((address.get(key) for key in ("state_district", "district", "county") if address.get(key)), "")
            return {"locality": str(locality), "district": str(district)}
        except (WeatherServiceError, AttributeError, TypeError):
            return {}

    @staticmethod
    def _location_key(state,district,taluk,village,location,lat,lon):
        if lat is not None and lon is not None: return f"gps:{round(float(lat),2):.2f}:{round(float(lon),2):.2f}"
        return "|".join(str(v).strip().lower() for v in (state,district,taluk,village,location))

    def _resolve_location(self,*,state,district,taluk,village,location=""):
        attempts=[("village",village),("taluk",taluk),("district",district)]
        if location.strip(): attempts.insert(0,("location",location))
        for level,name in attempts:
            if not name.strip(): continue
            results=self._geocode(name=name,state=state)
            ranked=sorted(results,key=lambda x:self._location_score(x,name,district,taluk),reverse=True)
            if not ranked: continue
            best=ranked[0]; score=self._location_score(best,name,district,taluk)
            minimum=150 if level in {"village","taluk","location"} else 130
            if score<minimum: continue
            return {"name":best.get("name",name),"latitude":float(best["latitude"]),"longitude":float(best["longitude"]),"timezone":best.get("timezone"),"resolved_level":level,"match_score":score}
        raise WeatherServiceError(f"Could not resolve location. Village='{village}', Taluk='{taluk}', District='{district}'.")

    def _geocode(self,*,name,state):
        query=urlencode({"name":f"{name.strip()}, {state.strip()}","count":20,"language":"en","format":"json","countryCode":"IN"})
        payload=self._get_json(f"{GEOCODING_URL}?{query}")
        return payload.get("results",[]) if isinstance(payload,dict) else []

    @staticmethod
    def _location_score(item,requested_name,district,taluk):
        score=0; requested=requested_name.strip().lower(); name=str(item.get("name","")).strip().lower()
        admins={str(item.get(k,"")).strip().lower() for k in ("admin2","admin3","admin4")}
        if name==requested: score+=120
        elif name.startswith(requested): score+=50
        if str(item.get("admin1","")).strip().lower() in {"karnataka","ka"}: score+=50
        if district.strip().lower() in admins: score+=50
        if taluk.strip().lower() in admins: score+=30
        code=str(item.get("feature_code","")).upper()
        if code.startswith("PPL") or code.startswith("ADM"): score+=10
        return score

    def _fetch_forecast(self,latitude,longitude):
        query=urlencode({"latitude":latitude,"longitude":longitude,
            "current":"temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation,weather_code",
            "hourly":"temperature_2m,precipitation_probability,precipitation,weather_code,et0_fao_evapotranspiration",
            "daily":"temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,weather_code,et0_fao_evapotranspiration",
            "forecast_days":7,"timezone":"auto","temperature_unit":"celsius","wind_speed_unit":"kmh","precipitation_unit":"mm"})
        return self._get_json(f"{FORECAST_URL}?{query}")

    def _normalize(self,*,forecast,location,state,district,taluk,village,locality):
        current=forecast.get("current") or {}; hourly=forecast.get("hourly") or {}; daily=forecast.get("daily") or {}
        times=hourly.get("time") or []; start=self._current_hour_index(times,forecast); end=min(start+24,len(times))
        hourly_rows=[{"time":times[i],"temperature":self._number_at(hourly.get("temperature_2m"),i),"precipitation_probability":self._number_at(hourly.get("precipitation_probability"),i),"precipitation_mm":self._number_at(hourly.get("precipitation"),i),"weather_code":self._int_at(hourly.get("weather_code"),i)} for i in range(start,end)]
        daily_rows=[{"date":str(date),"temperature_max":self._number_at(daily.get("temperature_2m_max"),i),"temperature_min":self._number_at(daily.get("temperature_2m_min"),i),"precipitation_mm":self._number_at(daily.get("precipitation_sum"),i),"precipitation_probability":self._number_at(daily.get("precipitation_probability_max"),i),"et0_mm":self._number_at(daily.get("et0_fao_evapotranspiration"),i),"weather_code":self._int_at(daily.get("weather_code"),i)} for i,date in enumerate((daily.get("time") or [])[:7])]
        rain_prob=max((float(r.get("precipitation_probability") or 0) for r in hourly_rows),default=0)
        rain_mm=sum(float(r.get("precipitation_mm") or 0) for r in hourly_rows)
        et0=sum(float(self._number_at(hourly.get("et0_fao_evapotranspiration"),i) or 0) for i in range(start,end))
        wind=float(current.get("wind_speed_10m") or 0); humidity=float(current.get("relative_humidity_2m") or 0); code=self._int(current.get("weather_code"))
        local_hour=(datetime.now(timezone.utc)+timedelta(seconds=int(forecast.get('utc_offset_seconds') or 0))).hour
        guidance=self._guidance(rain_prob,rain_mm,wind,humidity,code,local_hour)
        return {"source":"Open-Meteo","location":{"name":location["name"],"state":state,"district":district,"taluk":taluk,"village":village,"latitude":location["latitude"],"longitude":location["longitude"],"timezone":forecast.get("timezone"),"resolved_level":location["resolved_level"],"match_score":location.get("match_score")},"place":{"district":district or None,"locality":locality or location["name"]},"current":{"temperature":self._number(current.get("temperature_2m")),"humidity":self._number(current.get("relative_humidity_2m")),"wind_kmh":self._number(current.get("wind_speed_10m")),"precipitation_mm":self._number(current.get("precipitation")),"rain_mm":self._number(current.get("precipitation")),"weather_code":code},"hourly":hourly_rows,"daily":daily_rows,"next_24h":{"precipitation_mm":round(rain_mm,2),"precipitation_probability_max":round(rain_prob,1),"et0_mm":round(et0,2)},"guidance":guidance,"updated_at":datetime.now(timezone.utc).isoformat(),"fetched_at":datetime.now(timezone.utc).isoformat()}

    @staticmethod
    def _guidance(rain_probability,precipitation,wind,humidity,weather_code,local_hour):
        thunder=weather_code in THUNDERSTORM_CODES
        outside_field_hours=local_hour < FIELD_WORK_START_HOUR or local_hour >= FIELD_WORK_END_HOUR
        if outside_field_hours:
            return {'spraying':'Not suitable','drying':'Not suitable','transport':'Not suitable','irrigation':'Check soil','status_line':'Outside preferred field-work hours'}
        spraying="Suitable" if not thunder and rain_probability<=SPRAY_MAX_RAIN_PROBABILITY and precipitation<=SPRAY_MAX_RAIN_MM and wind<=SPRAY_MAX_WIND_KMH else ("Avoid" if thunder or rain_probability>=65 or wind>SPRAY_MAX_WIND_KMH else "Caution")
        drying="Suitable" if not thunder and rain_probability<=DRYING_MAX_RAIN_PROBABILITY and humidity<=DRYING_MAX_HUMIDITY else ("Avoid" if thunder or rain_probability>=60 else "Caution")
        transport="Suitable" if not thunder and rain_probability<=HARVEST_MAX_RAIN_PROBABILITY and wind<=HARVEST_MAX_WIND_KMH else ("Avoid" if thunder or wind>HARVEST_MAX_WIND_KMH else "Caution")
        irrigation="Not required" if precipitation>=IRRIGATION_RAIN_MM or rain_probability>=IRRIGATION_RAIN_PROBABILITY else ("Until afternoon" if rain_probability>=35 else "Check soil")
        status="Thunderstorm risk" if thunder else ("Rain likely later today" if rain_probability>=65 else ("Weather may change during field work" if rain_probability>=35 else ("Humidity is high" if humidity>=85 else "Weather suitable for field work")))
        return {"spraying":spraying,"drying":drying,"transport":transport,"irrigation":irrigation,"status_line":status}

    @staticmethod
    def _current_hour_index(times,forecast):
        now=datetime.now(timezone.utc)+timedelta(seconds=int(forecast.get("utc_offset_seconds") or 0)); target=now.replace(minute=0,second=0,microsecond=0).replace(tzinfo=None)
        for i,raw in enumerate(times):
            try:
                if datetime.fromisoformat(str(raw))>=target:return i
            except ValueError: pass
        return max(0,len(times)-24)

    @staticmethod
    def _number(v): return float(v) if isinstance(v,(int,float)) else None
    @staticmethod
    def _int(v): return int(v) if isinstance(v,(int,float)) else None
    @staticmethod
    def _number_at(values,index): return OpenMeteoWeatherService._number(values[index] if values and index<len(values) else None)
    @staticmethod
    def _int_at(values,index): return OpenMeteoWeatherService._int(values[index] if values and index<len(values) else None)

    @staticmethod
    def _get_json(url):
        request=Request(url,headers={"User-Agent":"ArecaSmart/1.0"},method="GET")
        try:
            with urlopen(request,timeout=12) as response:
                payload=json.loads(response.read().decode("utf-8"))
                if isinstance(payload,dict) and payload.get("error"): raise WeatherServiceError(str(payload.get("reason","Weather provider returned an error.")))
                return payload
        except HTTPError as exc:
            detail=exc.read().decode("utf-8",errors="replace"); raise WeatherServiceError(f"Weather provider request failed ({exc.code}): {detail[:200]}") from exc
        except (URLError,TimeoutError,ValueError) as exc:
            raise WeatherServiceError("Weather provider is temporarily unavailable.") from exc
