class WeatherDay {
  final String date;
  final double? temperatureMax;
  final double? temperatureMin;
  final double? precipitationMm;
  final double? precipitationProbability;
  final double? et0Mm;
  final int? weatherCode;

  const WeatherDay({
    required this.date,
    this.temperatureMax,
    this.temperatureMin,
    this.precipitationMm,
    this.precipitationProbability,
    this.et0Mm,
    this.weatherCode,
  });

  factory WeatherDay.fromMap(Map<String, dynamic> map) => WeatherDay(
        date: map['date']?.toString() ?? '',
        temperatureMax: (map['temperature_max'] as num?)?.toDouble(),
        temperatureMin: (map['temperature_min'] as num?)?.toDouble(),
        precipitationMm: (map['precipitation_mm'] as num?)?.toDouble(),
        precipitationProbability:
            (map['precipitation_probability'] as num?)?.toDouble(),
        et0Mm: (map['et0_mm'] as num?)?.toDouble(),
        weatherCode: (map['weather_code'] as num?)?.toInt(),
      );
}

class WeatherData {
  final String source;
  final String locationName;
  final String resolvedLevel;
  final String timezone;
  final double latitude;
  final double longitude;
  final double? temperature;
  final double? humidity;
  final double? precipitationMm;
  final double? rainMm;
  final int? weatherCode;
  final double next24hPrecipitationMm;
  final double next24hPrecipitationProbability;
  final double next24hEt0Mm;
  final DateTime fetchedAt;
  final List<WeatherDay> forecast;

  const WeatherData({
    required this.source,
    required this.locationName,
    required this.resolvedLevel,
    required this.timezone,
    required this.latitude,
    required this.longitude,
    this.temperature,
    this.humidity,
    this.precipitationMm,
    this.rainMm,
    this.weatherCode,
    required this.next24hPrecipitationMm,
    required this.next24hPrecipitationProbability,
    required this.next24hEt0Mm,
    required this.fetchedAt,
    required this.forecast,
  });

  factory WeatherData.fromMap(Map<String, dynamic> map) {
    final location = Map<String, dynamic>.from(map['location'] as Map? ?? {});
    final current = Map<String, dynamic>.from(map['current'] as Map? ?? {});
    final next24h = Map<String, dynamic>.from(map['next_24h'] as Map? ?? {});
    final forecast = (map['forecast'] as List? ?? [])
        .whereType<Map>()
        .map((item) => WeatherDay.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    return WeatherData(
      source: map['source']?.toString() ?? 'Open-Meteo',
      locationName: location['name']?.toString() ?? '',
      resolvedLevel: location['resolved_level']?.toString() ?? '',
      timezone: location['timezone']?.toString() ?? '',
      latitude: (location['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (location['longitude'] as num?)?.toDouble() ?? 0,
      temperature: (current['temperature'] as num?)?.toDouble(),
      humidity: (current['humidity'] as num?)?.toDouble(),
      precipitationMm:
          (current['precipitation_mm'] as num?)?.toDouble(),
      rainMm: (current['rain_mm'] as num?)?.toDouble(),
      weatherCode: (current['weather_code'] as num?)?.toInt(),
      next24hPrecipitationMm:
          (next24h['precipitation_mm'] as num?)?.toDouble() ?? 0,
      next24hPrecipitationProbability:
          (next24h['precipitation_probability_max'] as num?)?.toDouble() ?? 0,
      next24hEt0Mm: (next24h['et0_mm'] as num?)?.toDouble() ?? 0,
      fetchedAt: DateTime.tryParse(map['fetched_at']?.toString() ?? '') ??
          DateTime.now(),
      forecast: forecast,
    );
  }

  String get weatherDescription {
    switch (weatherCode) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 95:
      case 96:
      case 97:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Weather data';
    }
  }
}
