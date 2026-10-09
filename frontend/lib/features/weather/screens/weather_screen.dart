import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/backend/backend_api.dart';
import '../../../services/backend/weather_cache_service.dart';
import '../../../core/services/device_location_service.dart';
import '../../../models/weather/weather_model.dart';
import '../../weather/widgets/manual_location_picker.dart';
import '../../../widgets/app_navigation_scaffold.dart';

class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});
  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  WeatherData? _weather;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    final locationService = ref.read(deviceLocationServiceProvider);
    final api = ref.read(backendApiProvider);
    final cache = ref.read(weatherCacheServiceProvider);

    if (mounted) {
      setState(() {
        _loading = true;
        if (refresh) _error = null;
      });
    }

    try {
      final location = await locationService.resolveCurrentLocation();
      WeatherData weather;

      if (location != null) {
        weather = await api.getWeatherByCoordinates(
          latitude: location.latitude,
          longitude: location.longitude,
          label: location.label,
        );
      } else {
        final saved = await locationService.loadLastWeatherPlace();
        weather = saved != null
            ? await api.getWeatherByPlace(
                district: saved['district']!,
                taluk: saved['taluk']!,
                village: saved['village']!,
              )
            : await api.getWeatherByPlace(district: 'Shivamogga');
      }

      await cache.save(_toMap(weather));

      if (!mounted) return;
      setState(() {
        _weather = weather;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      final cached = await cache.load();

      if (cached != null) {
        try {
          final weather = WeatherData.fromMap(cached);
          if (!mounted) return;
          setState(() {
            _weather = weather;
            _loading = false;
            _error = e.toString().replaceFirst('Exception: ', '');
          });
          return;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Map<String, dynamic> _toMap(WeatherData weather) {
    return {
      'source': weather.source,
      'location': {
        'name': weather.locationName,
        'resolved_level': weather.resolvedLevel,
        'timezone': weather.timezone,
        'latitude': weather.latitude,
        'longitude': weather.longitude,
      },
      'place': {'district': weather.district, 'locality': weather.locality},
      'current': {
        'temperature': weather.temperature,
        'humidity': weather.humidity,
        'wind_kmh': weather.windKmh,
        'precipitation_mm': weather.precipitationMm,
        'rain_mm': weather.rainMm,
        'weather_code': weather.weatherCode,
      },
      'next_24h': {
        'precipitation_mm': weather.next24hPrecipitationMm,
        'precipitation_probability_max':
            weather.next24hPrecipitationProbability,
        'et0_mm': weather.next24hEt0Mm,
      },
      'hourly': weather.hourly
          .map(
            (hour) => {
              'time': hour.time,
              'temperature': hour.temperature,
              'precipitation_probability': hour.precipitationProbability,
              'precipitation_mm': hour.precipitationMm,
              'weather_code': hour.weatherCode,
            },
          )
          .toList(),
      'daily': weather.forecast
          .map(
            (day) => {
              'date': day.date,
              'temperature_max': day.temperatureMax,
              'temperature_min': day.temperatureMin,
              'precipitation_mm': day.precipitationMm,
              'precipitation_probability': day.precipitationProbability,
              'et0_mm': day.et0Mm,
              'weather_code': day.weatherCode,
            },
          )
          .toList(),
      'guidance': {
        'spraying': weather.guidance.spraying,
        'drying': weather.guidance.drying,
        'transport': weather.guidance.transport,
        'irrigation': weather.guidance.irrigation,
        'status_line': weather.guidance.statusLine,
      },
      'updated_at': weather.updatedAt.toIso8601String(),
      'fetched_at': weather.fetchedAt.toIso8601String(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weather = _weather;
    return AppNavigationScaffold(
      title: 'Weather',
      selectedIndex: 1,
      actions: [
        IconButton(
          onPressed: () => _load(refresh: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _errorBanner(scheme, _error!),
                  TextButton.icon(
                    onPressed: () => showManualLocationPicker(
                      context,
                      ref,
                      onSelected: (district, taluk, village) async {
                        final selected = await ref
                            .read(backendApiProvider)
                            .getWeatherByPlace(
                              district: district,
                              taluk: taluk,
                              village: village,
                            );
                        if (!mounted) return;
                        setState(() {
                          _weather = selected;
                          _error = null;
                        });
                      },
                    ),
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Choose Karnataka location'),
                  ),
                ],
              ),
            _hero(context, weather),
            if (_loading && weather == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (weather != null) ...[
              _section(context, "Today's farm guidance"),
              _guidance(context, weather),
              _section(context, 'Hourly forecast'),
              _hourly(context, weather),
              _section(context, '7-day forecast'),
              _daily(context, weather),
              _rainChips(context, weather),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(ColorScheme scheme, String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        error,
        style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _hero(BuildContext context, WeatherData? weather) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather?.locationName ?? 'Current location',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      weather?.district ?? 'Local weather',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _load(refresh: true),
                icon: Icon(Icons.refresh_rounded, color: scheme.onPrimary),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather == null
                          ? '--°C'
                          : '${weather.temperature?.round() ?? '--'}°C',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 43,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      weather?.weatherDescription ?? 'Loading weather',
                      style: TextStyle(color: scheme.onPrimary, fontSize: 15),
                    ),
                  ],
                ),
              ),
              Icon(
                _glyph(weather?.weatherCode),
                color: scheme.onPrimary,
                size: 56,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            weather?.guidance.statusLine ?? 'Getting local weather',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric(
                scheme,
                'Rain chance',
                '${weather?.next24hPrecipitationProbability.round() ?? '--'}%',
              ),
              _metric(
                scheme,
                'Humidity',
                '${weather?.humidity?.round() ?? '--'}%',
              ),
              _metric(
                scheme,
                'Wind',
                '${weather?.windKmh?.round() ?? '--'} km/h',
              ),
              _metric(
                scheme,
                'Max/Min',
                weather?.forecast.isNotEmpty == true
                    ? '${weather!.forecast.first.temperatureMax?.round() ?? '--'}° / ${weather.forecast.first.temperatureMin?.round() ?? '--'}°'
                    : '-- / --',
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (weather != null)
            Text(
              'Updated ${TimeOfDay.fromDateTime(weather.updatedAt).format(context)}',
              style: TextStyle(
                color: scheme.onPrimary.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(ColorScheme scheme, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.65),
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _guidance(BuildContext context, WeatherData weather) {
    final rows = [
      ['Spraying', weather.guidance.spraying],
      ['Drying produce', weather.guidance.drying],
      ['Harvest and transport', weather.guidance.transport],
      ['Irrigation', weather.guidance.irrigation],
    ];
    return Card(
      child: Column(
        children: rows
            .map(
              (row) => ListTile(
                title: Text(row[0]),
                trailing: _status(context, row[1]),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _status(BuildContext context, String value) {
    final scheme = Theme.of(context).colorScheme;
    const good = {'Suitable', 'Not required', 'Check soil', 'Until afternoon'};
    const avoid = {'Avoid', 'Not suitable'};
    final color = avoid.contains(value)
        ? scheme.error
        : good.contains(value)
        ? scheme.primary
        : scheme.tertiary;
    return Text(
      value,
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }

  Widget _hourly(BuildContext context, WeatherData weather) {
    return SizedBox(
      height: 135,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: weather.hourly.length,
        itemBuilder: (context, index) {
          final hour = weather.hourly[index];
          final dateTime = DateTime.tryParse(hour.time);
          return Container(
            width: 84,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  dateTime == null
                      ? '--'
                      : TimeOfDay.fromDateTime(dateTime).format(context),
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 9),
                Icon(_glyph(hour.weatherCode), size: 22),
                const SizedBox(height: 7),
                Text(
                  '${hour.temperature?.round() ?? '--'}°',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${hour.precipitationProbability?.round() ?? 0}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
      ),
    );
  }

  Widget _daily(BuildContext context, WeatherData weather) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: weather.forecast.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          final date = DateTime.tryParse(day.date);
          final weekday = date == null
              ? day.date
              : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
          final isToday = date != null && DateUtils.isSameDay(date, DateTime.now());
          return Container(
            decoration: BoxDecoration(
              border: index == weather.forecast.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text(isToday ? 'Today' : weekday, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface))),
                Expanded(flex: 2, child: Text('${day.precipitationProbability?.round() ?? 0}%', textAlign: TextAlign.center, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800))),
                Expanded(flex: 4, child: Text('${day.temperatureMin?.round() ?? '--'}° / ${day.temperatureMax?.round() ?? '--'}°', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w500))),
                Expanded(flex: 3, child: Text('${(day.precipitationMm ?? 0).toStringAsFixed(1)} mm', textAlign: TextAlign.end, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _rainChips(BuildContext context, WeatherData weather) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: weather.forecast.map((day) {
          final date = DateTime.tryParse(day.date);
          final label = date == null
              ? '--'
              : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];
          return Chip(
            label: Text(
              '${label} ${day.precipitationProbability?.round() ?? 0}%',
            ),
          );
        }).toList(),
      ),
    );
  }

  static IconData _glyph(int? code) {
    if (code == null) return Icons.cloud_outlined;
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code < 4) return Icons.cloud_outlined;
    if (code < 50) return Icons.foggy;
    if (code < 70) return Icons.grain;
    if (code < 90) return Icons.water_drop_outlined;
    return Icons.thunderstorm_outlined;
  }
}
