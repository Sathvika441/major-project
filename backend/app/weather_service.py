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


class WeatherServiceError(RuntimeError):
    """Raised when weather or location data cannot be resolved."""


class OpenMeteoWeatherService:
    def __init__(self) -> None:
        self._cache: dict[str, tuple[datetime, dict]] = {}

    def get_weather(
        self,
        *,
        state: str,
        district: str,
        taluk: str,
        village: str,
    ) -> dict:
        location_key = self._location_key(state, district, taluk, village)
        cached = self._cache.get(location_key)
        now = datetime.now(timezone.utc)
        if cached and now - cached[0] < CACHE_TTL:
            return cached[1]

        location = self._resolve_location(
            state=state,
            district=district,
            taluk=taluk,
            village=village,
        )
        forecast = self._fetch_forecast(location["latitude"], location["longitude"])
        result = self._normalize(
            forecast=forecast,
            location=location,
            state=state,
            district=district,
            taluk=taluk,
            village=village,
        )
        self._cache[location_key] = (now, result)
        return result

    @staticmethod
    def _location_key(
        state: str,
        district: str,
        taluk: str,
        village: str,
    ) -> str:
        return "|".join(
            value.strip().lower()
            for value in (state, district, taluk, village)
        )

    def _resolve_location(
        self,
        *,
        state: str,
        district: str,
        taluk: str,
        village: str,
    ) -> dict:
        candidates = []
        for name, level in (
            (village, "village"),
            (taluk, "taluk"),
            (district, "district"),
        ):
            if not name.strip():
                continue
            results = self._geocode(name=name, state=state)
            ranked = sorted(
                results,
                key=lambda item: self._location_score(
                    item,
                    requested_name=name,
                    district=district,
                    taluk=taluk,
                ),
                reverse=True,
            )
            if ranked:
                candidates.append((level, ranked[0]))

        if not candidates:
            raise WeatherServiceError(
                "Could not resolve the farm location to coordinates. "
                "Please check the selected village, taluk and district."
            )

        level, match = candidates[0]
        return {
            "name": match.get("name", village or taluk or district),
            "latitude": float(match["latitude"]),
            "longitude": float(match["longitude"]),
            "timezone": match.get("timezone"),
            "resolved_level": level,
            "admin1": match.get("admin1"),
            "admin2": match.get("admin2"),
            "admin3": match.get("admin3"),
        }

    def _geocode(self, *, name: str, state: str) -> list[dict]:
        query = urlencode(
            {
                "name": f"{name}, {state}",
                "count": 10,
                "language": "en",
                "format": "json",
                "countryCode": "IN",
            }
        )
        payload = self._get_json(f"{GEOCODING_URL}?{query}")
        return payload.get("results", []) if isinstance(payload, dict) else []

    @staticmethod
    def _location_score(
        item: dict,
        *,
        requested_name: str,
        district: str,
        taluk: str,
    ) -> int:
        score = 0
        requested = requested_name.strip().lower()
        name = str(item.get("name", "")).strip().lower()
        admin1 = str(item.get("admin1", "")).strip().lower()
        admin2 = str(item.get("admin2", "")).strip().lower()
        admin3 = str(item.get("admin3", "")).strip().lower()

        if name == requested:
            score += 100
        elif name.startswith(requested):
            score += 40
        if admin1 in {"karnataka", "ka"}:
            score += 30
        if district.strip().lower() == admin2:
            score += 20
        if taluk.strip().lower() in {admin2, admin3}:
            score += 15
        if item.get("latitude") is not None and item.get("longitude") is not None:
            score += 5
        return score

    def _fetch_forecast(self, latitude: float, longitude: float) -> dict:
        query = urlencode(
            {
                "latitude": latitude,
                "longitude": longitude,
                "current": ",".join(
                    [
                        "temperature_2m",
                        "relative_humidity_2m",
                        "precipitation",
                        "rain",
                        "weather_code",
                    ]
                ),
                "hourly": ",".join(
                    [
                        "temperature_2m",
                        "relative_humidity_2m",
                        "precipitation_probability",
                        "precipitation",
                        "et0_fao_evapotranspiration",
                    ]
                ),
                "daily": ",".join(
                    [
                        "temperature_2m_max",
                        "temperature_2m_min",
                        "precipitation_sum",
                        "precipitation_probability_max",
                        "et0_fao_evapotranspiration",
                        "weather_code",
                    ]
                ),
                "forecast_days": 3,
                "timezone": "auto",
                "temperature_unit": "celsius",
                "precipitation_unit": "mm",
            }
        )
        return self._get_json(f"{FORECAST_URL}?{query}")

    def _normalize(
        self,
        *,
        forecast: dict,
        location: dict,
        state: str,
        district: str,
        taluk: str,
        village: str,
    ) -> dict:
        current = forecast.get("current") or {}
        hourly = forecast.get("hourly") or {}
        daily = forecast.get("daily") or {}

        hourly_times = hourly.get("time") or []
        now_local = self._local_now(forecast)
        start_index = 0
        for index, raw_time in enumerate(hourly_times):
            try:
                hour = datetime.fromisoformat(str(raw_time))
            except ValueError:
                continue
            if hour >= now_local.replace(minute=0, second=0, microsecond=0):
                start_index = index
                break
        else:
            start_index = max(0, len(hourly_times) - 24)

        end_index = min(start_index + 24, len(hourly_times))
        precipitation = self._slice_numbers(
            hourly.get("precipitation"), start_index, end_index
        )
        precipitation_probability = self._slice_numbers(
            hourly.get("precipitation_probability"), start_index, end_index
        )
        et0 = self._slice_numbers(
            hourly.get("et0_fao_evapotranspiration"), start_index, end_index
        )

        next_24h = {
            "precipitation_mm": round(sum(precipitation), 2),
            "precipitation_probability_max": round(
                max(precipitation_probability, default=0.0), 1
            ),
            "et0_mm": round(sum(et0), 2),
        }

        days = []
        times = daily.get("time") or []
        max_temps = daily.get("temperature_2m_max") or []
        min_temps = daily.get("temperature_2m_min") or []
        rain_sums = daily.get("precipitation_sum") or []
        rain_probs = daily.get("precipitation_probability_max") or []
        et0_days = daily.get("et0_fao_evapotranspiration") or []
        codes = daily.get("weather_code") or []

        for index, date in enumerate(times[:3]):
            days.append(
                {
                    "date": str(date),
                    "temperature_max": self._number_at(max_temps, index),
                    "temperature_min": self._number_at(min_temps, index),
                    "precipitation_mm": self._number_at(rain_sums, index),
                    "precipitation_probability": self._number_at(rain_probs, index),
                    "et0_mm": self._number_at(et0_days, index),
                    "weather_code": self._int_at(codes, index),
                }
            )

        return {
            "source": "Open-Meteo",
            "location": {
                "name": location["name"],
                "state": state,
                "district": district,
                "taluk": taluk,
                "village": village,
                "latitude": location["latitude"],
                "longitude": location["longitude"],
                "timezone": forecast.get("timezone"),
                "resolved_level": location["resolved_level"],
            },
            "current": {
                "temperature": self._number(current.get("temperature_2m")),
                "humidity": self._number(current.get("relative_humidity_2m")),
                "precipitation_mm": self._number(current.get("precipitation")),
                "rain_mm": self._number(current.get("rain")),
                "weather_code": self._int(current.get("weather_code")),
            },
            "next_24h": next_24h,
            "forecast": days,
            "fetched_at": datetime.now(timezone.utc).isoformat(),
        }

    @staticmethod
    def _local_now(forecast: dict) -> datetime:
        offset = int(forecast.get("utc_offset_seconds") or 0)
        return (datetime.now(timezone.utc) + timedelta(seconds=offset)).replace(
            tzinfo=None
        )

    @staticmethod
    def _slice_numbers(values, start: int, end: int) -> list[float]:
        result = []
        for value in (values or [])[start:end]:
            number = OpenMeteoWeatherService._number(value)
            if number is not None:
                result.append(number)
        return result

    @staticmethod
    def _number(value) -> float | None:
        return float(value) if isinstance(value, (int, float)) else None

    @staticmethod
    def _int(value) -> int | None:
        return int(value) if isinstance(value, (int, float)) else None

    @staticmethod
    def _number_at(values, index: int) -> float | None:
        return OpenMeteoWeatherService._number(
            values[index] if index < len(values) else None
        )

    @staticmethod
    def _int_at(values, index: int) -> int | None:
        return OpenMeteoWeatherService._int(
            values[index] if index < len(values) else None
        )

    @staticmethod
    def _get_json(url: str) -> dict:
        request = Request(
            url,
            headers={"User-Agent": "ArecaSmart/1.0"},
            method="GET",
        )
        try:
            with urlopen(request, timeout=12) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise WeatherServiceError(
                f"Weather provider request failed ({exc.code}): {detail[:200]}"
            ) from exc
        except (URLError, TimeoutError, ValueError) as exc:
            raise WeatherServiceError(
                "Weather provider is temporarily unavailable."
            ) from exc
