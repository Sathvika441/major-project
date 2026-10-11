import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/farm/farm_model.dart';
import '../../../models/weather/weather_model.dart';
import '../../../repositories/farm/farm_repository.dart';
import '../../../services/backend/backend_api.dart';
import '../../../widgets/app_navigation_scaffold.dart';
import 'farm_details_screen.dart';

class FarmWorkspaceScreen extends ConsumerStatefulWidget {
  final FarmModel farm;
  const FarmWorkspaceScreen({super.key, required this.farm});
  @override
  ConsumerState<FarmWorkspaceScreen> createState() =>
      _FarmWorkspaceScreenState();
}

class _FarmWorkspaceScreenState extends ConsumerState<FarmWorkspaceScreen> {
  WeatherData? weather;
  String? error;
  bool loading = true;
  late FarmModel _farm;

  @override
  void initState() {
    super.initState();
    _farm = widget.farm;
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final f = _farm;
      final result = await ref
          .read(backendApiProvider)
          .getWeatherByPlace(
            district: f.district,
            taluk: f.taluk,
            village: f.village,
          );
      if (mounted)
        setState(() {
          weather = result;
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          loading = false;
        });
    }
  }

  Future<void> _editFarm() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FarmDetailsScreen(farmId: _farm.id)),
    );
    if (!mounted) return;
    try {
      final farms = await ref
          .read(farmRepositoryProvider)
          .getFarms(_farm.userId);
      final updated = farms.where((farm) => farm.id == _farm.id);
      if (updated.isNotEmpty && mounted) setState(() => _farm = updated.first);
    } catch (_) {
      // Keep the current saved farm visible if a refresh temporarily fails.
    }
    if (mounted) _loadWeather();
  }

  @override
  Widget build(BuildContext context) {
    final f = _farm;
    final scheme = Theme.of(context).colorScheme;
    final place = weather?.locality?.isNotEmpty == true
        ? weather!.locality!
        : weather?.district?.isNotEmpty == true
        ? weather!.district!
        : f.village.isNotEmpty
        ? f.village
        : f.district;
    final rainChance = weather?.next24hPrecipitationProbability ?? 0;
    final rainMm = weather?.next24hPrecipitationMm ?? 0;
    final rainExpected = weather != null && (rainChance >= 65 || rainMm >= 3);

    return AppNavigationScaffold(
      title: f.name.isEmpty ? 'Farm workspace' : f.name,
      subtitle: [
        f.village,
        f.district,
      ].where((v) => v.trim().isNotEmpty).join(' • '),
      selectedIndex: 2,
      actions: [
        IconButton(
          tooltip: 'Edit farm',
          onPressed: _editFarm,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Refresh weather',
          onPressed: _loadWeather,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadWeather,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: .22),
                      scheme.surface,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            place.isEmpty ? 'Farm location' : place,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (loading && weather == null)
                      const LinearProgressIndicator()
                    else if (error != null && weather == null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Farm weather unavailable: $error'),
                          TextButton.icon(
                            onPressed: _loadWeather,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      )
                    else ...[
                      Text(
                        '${weather?.temperature?.round() ?? '--'}°C',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        weather?.weatherDescription ?? 'Weather unavailable',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(
                            icon: Icons.water_drop_outlined,
                            label:
                                'Rain ${weather?.next24hPrecipitationProbability.round() ?? '--'}%',
                          ),
                          _Chip(
                            icon: Icons.air_rounded,
                            label:
                                'Wind ${weather?.windKmh?.round() ?? '--'} km/h',
                          ),
                          _Chip(
                            icon: Icons.opacity_rounded,
                            label:
                                'Humidity ${weather?.humidity?.round() ?? '--'}%',
                          ),
                        ],
                      ),
                      if (weather?.forecast.isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        Text(
                          '7-day forecast',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        ...weather!.forecast
                            .take(7)
                            .map(
                              (d) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(d.date)),
                                    Text(
                                      '${d.precipitationProbability?.round() ?? 0}%',
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${d.temperatureMin?.round() ?? '--'}° / ${d.temperatureMax?.round() ?? '--'}°',
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${(d.precipitationMm ?? 0).toStringAsFixed(1)} mm',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.water_drop_rounded,
                          color: scheme.tertiary,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Smart irrigation',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'READY TO CONFIGURE',
                            style: TextStyle(
                              color: scheme.onTertiaryContainer,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      weather == null
                          ? 'Weather data needed'
                          : rainExpected
                          ? 'Rain may meet some water needs'
                          : 'Check soil moisture before watering',
                      style: TextStyle(
                        color: rainExpected ? scheme.tertiary : scheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      weather == null
                          ? 'Refresh weather and verify this farm’s saved village, taluk and district.'
                          : rainExpected
                          ? 'Next 24 hours: ${rainChance.round()}% rain chance and ${rainMm.toStringAsFixed(1)} mm expected. Check drainage and soil moisture before irrigation.'
                          : 'No strong rainfall signal in the forecast. Check root-zone moisture and crop stage before deciding irrigation duration.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip(
                          icon: Icons.eco_outlined,
                          label: f.crop.isEmpty ? 'Arecanut' : f.crop,
                        ),
                        _Chip(
                          icon: Icons.water_drop_outlined,
                          label: f.irrigationMethod.isEmpty
                              ? 'Irrigation not set'
                              : f.irrigationMethod,
                        ),
                        _Chip(
                          icon: Icons.grass_outlined,
                          label: f.soilType.isEmpty
                              ? 'Soil type not set'
                              : f.soilType,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.sensors_outlined),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hardware placeholder: no live soil-moisture or pump telemetry is assumed. Guidance is weather-based and advisory only. No pump command will be sent until a compatible controller is connected and explicitly configured.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => context.go('/devices'),
                      icon: const Icon(Icons.sensors_rounded),
                      label: const Text('Set up sensors and devices'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Farm profile',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text('Size: ${f.sizeAcres.toStringAsFixed(1)} acres'),
                    Text('Water source: ${f.waterSource}'),
                    Text(
                      'Survey number: ${f.landSurveyNumber.isEmpty ? 'Not provided' : f.landSurveyNumber}',
                    ),
                    Text(
                      'Location: ${[f.village, f.taluk, f.district, f.state].where((v) => v.trim().isNotEmpty).join(', ')}',
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _editFarm,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit farm details'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
