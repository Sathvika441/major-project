class WeatherHour {
  final String time;
  final double? temperature;
  final double? precipitationProbability;
  final double? precipitationMm;
  final int? weatherCode;
  const WeatherHour({
    required this.time,
    this.temperature,
    this.precipitationProbability,
    this.precipitationMm,
    this.weatherCode,
  });
  factory WeatherHour.fromMap(Map<String, dynamic> m) => WeatherHour(
    time: m['time']?.toString() ?? '',
    temperature: (m['temperature'] as num?)?.toDouble(),
    precipitationProbability: (m['precipitation_probability'] as num?)
        ?.toDouble(),
    precipitationMm: (m['precipitation_mm'] as num?)?.toDouble(),
    weatherCode: (m['weather_code'] as num?)?.toInt(),
  );
}

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
  factory WeatherDay.fromMap(Map<String, dynamic> m) => WeatherDay(
    date: m['date']?.toString() ?? '',
    temperatureMax: (m['temperature_max'] as num?)?.toDouble(),
    temperatureMin: (m['temperature_min'] as num?)?.toDouble(),
    precipitationMm: (m['precipitation_mm'] as num?)?.toDouble(),
    precipitationProbability: (m['precipitation_probability'] as num?)
        ?.toDouble(),
    et0Mm: (m['et0_mm'] as num?)?.toDouble(),
    weatherCode: (m['weather_code'] as num?)?.toInt(),
  );
}

class WeatherGuidance {
  final String spraying, drying, transport, irrigation, statusLine;
  const WeatherGuidance({
    required this.spraying,
    required this.drying,
    required this.transport,
    required this.irrigation,
    required this.statusLine,
  });
  factory WeatherGuidance.fromMap(Map<String, dynamic> m) => WeatherGuidance(
    spraying: m['spraying']?.toString() ?? 'Caution',
    drying: m['drying']?.toString() ?? 'Caution',
    transport: m['transport']?.toString() ?? 'Caution',
    irrigation: m['irrigation']?.toString() ?? 'Check soil',
    statusLine: m['status_line']?.toString() ?? 'Weather data available',
  );
}

class WeatherData {
  final String source, locationName, resolvedLevel, timezone;
  final double latitude, longitude;
  final double? temperature, humidity, windKmh, precipitationMm, rainMm;
  final int? weatherCode;
  final double next24hPrecipitationMm,
      next24hPrecipitationProbability,
      next24hEt0Mm;
  final DateTime fetchedAt;
  final DateTime updatedAt;
  final List<WeatherHour> hourly;
  final List<WeatherDay> forecast;
  final WeatherGuidance guidance;
  final String? district, locality;
  const WeatherData({
    required this.source,
    required this.locationName,
    required this.resolvedLevel,
    required this.timezone,
    required this.latitude,
    required this.longitude,
    this.temperature,
    this.humidity,
    this.windKmh,
    this.precipitationMm,
    this.rainMm,
    this.weatherCode,
    required this.next24hPrecipitationMm,
    required this.next24hPrecipitationProbability,
    required this.next24hEt0Mm,
    required this.fetchedAt,
    required this.updatedAt,
    required this.hourly,
    required this.forecast,
    required this.guidance,
    this.district,
    this.locality,
  });
  factory WeatherData.fromMap(Map<String, dynamic> map) {
    final l = Map<String, dynamic>.from(map['location'] as Map? ?? {}),
        c = Map<String, dynamic>.from(map['current'] as Map? ?? {}),
        n = Map<String, dynamic>.from(map['next_24h'] as Map? ?? {}),
        p = Map<String, dynamic>.from(map['place'] as Map? ?? {}),
        g = WeatherGuidance.fromMap(
          Map<String, dynamic>.from(map['guidance'] as Map? ?? {}),
        );
    return WeatherData(
      source: map['source']?.toString() ?? 'Open-Meteo',
      locationName: l['name']?.toString() ?? 'Current location',
      resolvedLevel: l['resolved_level']?.toString() ?? '',
      timezone: l['timezone']?.toString() ?? '',
      latitude: (l['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (l['longitude'] as num?)?.toDouble() ?? 0,
      temperature: (c['temperature'] as num?)?.toDouble(),
      humidity: (c['humidity'] as num?)?.toDouble(),
      windKmh: (c['wind_kmh'] as num?)?.toDouble(),
      precipitationMm: (c['precipitation_mm'] as num?)?.toDouble(),
      rainMm: (c['rain_mm'] as num?)?.toDouble(),
      weatherCode: (c['weather_code'] as num?)?.toInt(),
      next24hPrecipitationMm: (n['precipitation_mm'] as num?)?.toDouble() ?? 0,
      next24hPrecipitationProbability:
          (n['precipitation_probability_max'] as num?)?.toDouble() ?? 0,
      next24hEt0Mm: (n['et0_mm'] as num?)?.toDouble() ?? 0,
      fetchedAt:
          DateTime.tryParse(map['fetched_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      hourly: (map['hourly'] as List? ?? [])
          .whereType<Map>()
          .map((x) => WeatherHour.fromMap(Map<String, dynamic>.from(x)))
          .toList(),
      forecast: (map['daily'] as List? ?? map['forecast'] as List? ?? [])
          .whereType<Map>()
          .map((x) => WeatherDay.fromMap(Map<String, dynamic>.from(x)))
          .toList(),
      guidance: g,
      district: p['district']?.toString(),
      locality: p['locality']?.toString(),
    );
  }
  String get weatherDescription => weatherDescriptionForCode(weatherCode);
}

String weatherDescriptionForCode(int? code) {
  switch (code) {
    case 0:
      return 'Clear Sky';
    case 1:
      return 'Mainly Clear';
    case 2:
      return 'Partly Cloudy';
    case 3:
      return 'Cloudy';
    case 45:
    case 48:
      return 'Fog';
    case 51:
    case 53:
    case 55:
      return 'Drizzle';
    case 56:
    case 57:
      return 'Freezing Drizzle';
    case 61:
    case 63:
    case 65:
      return 'Rain';
    case 66:
    case 67:
      return 'Freezing Rain';
    case 71:
      return 'Snow';
    case 73:
    case 75:
      return 'Snow Grains';
    case 77:
      return 'Snow Grains';
    case 80:
    case 81:
    case 82:
      return 'Rain Showers';
    case 85:
    case 86:
      return 'Snow Showers';
    case 95:
    case 96:
    case 97:
    case 98:
    case 99:
      return 'Thunderstorm';
    default:
      return 'Weather data';
  }
}
