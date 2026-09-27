import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/device/device_model.dart';
import '../../../models/farm/farm_model.dart';
import '../../../models/weather/weather_model.dart';
import '../../../repositories/device/device_repository.dart';
import '../../../repositories/farm/farm_repository.dart';
import '../../../services/backend/backend_api.dart';
import '../../../core/irrigation/irrigation_audit.dart';
import '../../../core/irrigation/irrigation_decision_engine.dart';
import '../../../core/irrigation/irrigation_models.dart';
import '../../../services/sensors/simulated_sensor_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../devices/screens/device_management_screen.dart';
import '../../farm/screens/farm_management_screen.dart';
import '../../profile/screens/profile_edit_screen.dart';
import '../../../widgets/app_navigation_scaffold.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final String? initialFarmId;

  const DashboardScreen({
    super.key,
    this.initialFarmId,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedFarmId;
  SensorReading? _demoReading;
  String _demoPreset = 'Normal';
  int? _selectedFarmCropAgeDays;
  double? _selectedFarmCropAgeYears;
  String? _selectedFarmGrowthStage;
  String? _selectedFarmPlantingDate;
  String? _decisionAuditKey;
  DateTime? _lastSyncAt;
  bool _syncing = false;
  PlatformFile? _mlImage;
  bool _mlUploading = false;
  Map<String, dynamic>? _mlResult;
  String? _mlError;
  WeatherData? _weather;
  String? _weatherError;
  bool _weatherLoading = false;
  String? _weatherFarmKey;

  SensorReading _presetReading(String preset) {
    final now = DateTime.now();
    final soilMoisture = switch (preset) {
      'Dry soil' => 18.0,
      'Wet soil' => 72.0,
      _ => 38.0,
    };
    return SensorReading(soilMoisture: soilMoisture, timestamp: now);
  }

  void _generateDemoReading() {
    setState(() {
      _demoReading = _presetReading(_demoPreset);
    });
  }

  Future<void> _refreshDashboard(String uid) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final farms = await ref.read(farmRepositoryProvider).getFarms(uid);
      await ref.read(deviceRepositoryProvider).getDevices(uid);
      if (mounted) {
        setState(() => _lastSyncAt = DateTime.now());
        if (farms.isNotEmpty) {
          final selected = farms.firstWhere(
            (item) => item.id == (widget.initialFarmId ?? _selectedFarmId),
            orElse: () => farms.first,
          );
          await _loadWeatherForFarm(selected, forceRefresh: true);
        }
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _loadWeatherForFarm(
    FarmModel farm, {
    bool forceRefresh = false,
  }) async {
    final key = '${farm.id}|${farm.state}|${farm.district}|${farm.taluk}|${farm.village}|${farm.location}';
    if (!forceRefresh &&
        _weatherFarmKey == key &&
        (_weatherLoading || _weather != null || _weatherError != null)) {
      return;
    }
    setState(() {
      _weatherFarmKey = key;
      _weatherLoading = true;
      _weatherError = null;
      if (forceRefresh) _weather = null;
    });
    try {
      final weather = await ref.read(backendApiProvider).getWeather(farm);
      if (!mounted || _weatherFarmKey != key) return;
      setState(() {
        _weather = weather;
        _weatherLoading = false;
        _weatherError = null;
      });
    } on BackendApiException catch (e) {
      if (!mounted || _weatherFarmKey != key) return;
      setState(() {
        _weatherLoading = false;
        _weather = null;
        _weatherError = e.message;
      });
    } catch (_) {
      if (!mounted || _weatherFarmKey != key) return;
      setState(() {
        _weatherLoading = false;
        _weather = null;
        _weatherError = 'Unable to load weather for this farm location.';
      });
    }
  }

  Widget _buildFarmPortfolio(BuildContext context, List<FarmModel> farms, String farmerName) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $farmerName',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a farm to open its smart agriculture workspace.',
                    style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9)),
                  ),
                ],
              );
              final action = FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onPrimary,
                  foregroundColor: scheme.primary,
                ),
                onPressed: () => context.push('/farms'),
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Add farm'),
              );
              return compact
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 18), action])
                  : Row(children: [Expanded(child: title), const SizedBox(width: 20), action]);
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Your farms',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${farms.length} ${farms.length == 1 ? 'farm' : 'farms'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1100 ? 3 : width >= 700 ? 2 : 1;
            const gap = 16.0;
            final cardWidth = columns == 1 ? width : (width - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: farms.map((farm) => SizedBox(
                width: cardWidth,
                child: _buildFarmCard(context, farm),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFarmCard(BuildContext context, FarmModel farm) {
    final scheme = Theme.of(context).colorScheme;
    final location = [farm.village, farm.taluk, farm.district]
        .where((e) => e.trim().isNotEmpty)
        .join(', ');
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/farm/${farm.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.agriculture_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      farm.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location.isEmpty ? farm.location : location,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(avatar: const Icon(Icons.square_foot_outlined, size: 16), label: Text('${farm.sizeAcres.toStringAsFixed(1)} acres')),
                  Chip(avatar: const Icon(Icons.eco_outlined, size: 16), label: Text(farm.crop)),
                  Chip(avatar: const Icon(Icons.water_outlined, size: 16), label: Text(farm.irrigationMethod)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.dashboard_customize_outlined, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Open farm workspace', style: TextStyle(fontWeight: FontWeight.w700))),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context, String farmerName, String? farmId) {
    return _buildAppDrawerForRoute(
      context,
      farmerName,
      farmId: farmId,
      selectedRoute: farmId == null ? '/dashboard' : 'farm',
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, VoidCallback onTap, {bool selected = false}) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      selected: selected,
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  Future<void> _pickMlImage(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;

    final file = picked.files.single;
    const maxImageBytes = 10 * 1024 * 1024;

    if (file.size > maxImageBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an image smaller than 10 MB.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _mlImage = file;
      _mlResult = null;
      _mlError = null;
      _mlUploading = false;
    });
  }

  Future<void> _predictMlImage(BuildContext context) async {
    final file = _mlImage;
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) {
      setState(() => _mlError = 'Please upload an image before predicting.');
      return;
    }

    setState(() {
      _mlResult = null;
      _mlError = null;
      _mlUploading = true;
    });

    try {
      final result = await ref.read(backendApiProvider).predictImage(
        bytes,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() {
        _mlResult = result;
        _mlUploading = false;
      });
    } on BackendApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mlUploading = false;
        _mlError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mlUploading = false;
        _mlError =
            'Unexpected error while contacting the ML service. Please try again.';
      });
    }
  }

  void _clearMlPrediction() {
    setState(() {
      _mlImage = null;
      _mlResult = null;
      _mlError = null;
      _mlUploading = false;
    });
  }

  String? _medicineForPrediction(String? prediction) {
    switch (prediction) {
      case 'Stem_bleeding':
        return 'Apply Tridemorph (0.1%) or Copper Oxychloride (5 g/L).';
      default:
        return null;
    }
  }

  Widget _buildMlPredictionCard(BuildContext context) {
    final result = _mlResult;
    final prediction = result?['prediction']?.toString();
    final confidence = result?['confidence'];
    final medicine = _medicineForPrediction(prediction);
    final hasImage = _mlImage?.bytes != null && _mlImage!.bytes!.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.biotech_outlined, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arecanut disease detection',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Upload an image, review the thumbnail, then tap Predict.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasImage) ...[
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: scheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  _mlImage!.bytes!,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('Unable to preview this image.'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _mlImage!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            if (!hasImage)
              FilledButton.icon(
                onPressed: _mlUploading
                    ? null
                    : () => _pickMlImage(context),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload image'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _mlUploading
                          ? null
                          : () => _predictMlImage(context),
                      icon: _mlUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _mlUploading ? 'Predicting...' : 'Predict',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _mlUploading ? null : _clearMlPrediction,
                    icon: const Icon(Icons.close),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            if (_mlError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _mlError!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10,
                      offset: Offset(0, 4),
                      color: Color(0x14000000),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Label:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prediction ?? 'Unknown',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Confidence:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      confidence is num
                          ? '${(confidence.toDouble() * 100).toStringAsFixed(2)}%'
                          : '—',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (medicine != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: 'Medicine\n',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: medicine),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testDemoBackend(BuildContext context, WidgetRef ref) async {
    final reading = _demoReading ?? _presetReading(_demoPreset);
    setState(() => _demoReading = reading);
    try {
      final result = await ref.read(backendApiProvider).predict({
        'soil_moisture': reading.soilMoisture,
        'temperature': reading.temperature,
        'humidity': reading.humidity,
        'rainfall': reading.rainfall,
        'crop': 'Arecanut',
        'crop_age_days': _selectedFarmCropAgeDays,
        'crop_age_years': _selectedFarmCropAgeYears,
        'growth_stage': _selectedFarmGrowthStage,
        'planting_date': _selectedFarmPlantingDate,
        'source': 'simulated',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            result['detail']?.toString() ?? 'Backend response received.',
          )),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Demo backend call (ML placeholder): $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final user = ref.watch(authControllerProvider).user;
    final uid = user?.uid;

    final isFarmWorkspace = widget.initialFarmId != null;

    return AppNavigationScaffold(
      title: isFarmWorkspace ? 'Farm workspace' : 'My farms',
      subtitle: isFarmWorkspace ? 'Monitor crop, weather and irrigation signals' : 'Your smart agriculture workspace',
      selectedIndex: 0,
      actions: [
        if (isFarmWorkspace)
          IconButton(
            tooltip: 'All farms',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.grid_view_rounded),
          ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: uid == null ? null : () => _refreshDashboard(uid),
          icon: _syncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
      body: uid == null
          ? const Center(child: Text('Please sign in.'))
          : StreamBuilder<List<FarmModel>>(
              stream: ref.read(farmRepositoryProvider).watchFarms(uid),
              builder: (context, farmsSnapshot) {
                if (farmsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (farmsSnapshot.hasError) {
                  return _syncError(
                    context,
                    'Could not synchronize farms',
                    'The dashboard could not reach farm data. Check your connection and try again.',
                    () => setState(() {}),
                  );
                }

                final farms = farmsSnapshot.data ?? [];
                if (farms.isEmpty) {
                  return _empty(
                    context,
                    'No farm configured',
                    'Complete onboarding or add a farm to view your dashboard.',
                  );
                }

                if (!isFarmWorkspace) {
                  return _buildFarmPortfolio(context, farms, user?.name ?? 'Farmer');
                }

                final selectedId = widget.initialFarmId ?? _selectedFarmId;
                final farm = farms.firstWhere(
                  (item) => item.id == selectedId,
                  orElse: () => farms.first,
                );
                final cropAgeDays = farm.cropAgeDays;
                final cropAgeYears = farm.cropAgeYears;
                final growthStage = farm.growthStageLabel;
                final plantingDate = farm.plantingDate?.toIso8601String();

                final farmChanged = _selectedFarmId != farm.id;
                if (farmChanged ||
                    _selectedFarmCropAgeDays != cropAgeDays ||
                    _selectedFarmGrowthStage != growthStage) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedFarmId = farm.id;
                        _selectedFarmCropAgeDays = cropAgeDays;
                        _selectedFarmCropAgeYears = cropAgeYears;
                        _selectedFarmGrowthStage = growthStage;
                        _selectedFarmPlantingDate = plantingDate;
                        if (farmChanged) {
                          _demoReading = _presetReading(_demoPreset);
                          _weather = null;
                          _weatherError = null;
                          _weatherFarmKey = null;
                        }
                      });
                      _loadWeatherForFarm(farm);
                    }
                  });
                }
                return StreamBuilder<List<DeviceModel>>(
                  stream: ref.read(deviceRepositoryProvider).watchDevices(uid),
                  builder: (context, deviceSnapshot) {
                    if (deviceSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (deviceSnapshot.hasError) {
                      return _syncError(
                        context,
                        'Could not synchronize sensor data',
                        'Farm details are available, but device data is offline or unavailable.',
                        () => setState(() {}),
                      );
                    }

                    final devices = deviceSnapshot.data ?? [];
                    final farmDevices =
                        devices.where((d) => d.farmId == farm.id).toList();
                    final alerts = _generateAlertsForFarm(
                      farmDevices,
                      _demoReading,
                      _weather,
                    );
                    final sensorAgg = _demoReading == null
                        ? _aggregate(farmDevices)
                        : _aggregateReading(_demoReading!);
                    final agg = _ReadingSummary(
                      soilMoisture: sensorAgg.soilMoisture,
                      temperature: _weather?.temperature ?? sensorAgg.temperature,
                      humidity: _weather?.humidity ?? sensorAgg.humidity,
                      rainfall: _weather?.rainMm ??
                          _weather?.precipitationMm ??
                          sensorAgg.rainfall,
                      count: sensorAgg.count,
                    );
                    final irrigationDecision =
                        _buildIrrigationDecision(farm, agg, _weather);
                    if (irrigationDecision != null) {
                      final auditKey = _decisionKey(
                        farm,
                        agg,
                        irrigationDecision,
                      );
                      if (_decisionAuditKey != auditKey) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _recordDashboardRecommendation(
                            irrigationDecision,
                            auditKey,
                            uid,
                          );
                        });
                      }
                    }

                    return RefreshIndicator(
                      onRefresh: () => _refreshDashboard(uid),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.primaryContainer,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Good day, ${user?.name ?? 'Farmer'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  farm.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withValues(alpha: 0.85),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        farm.location,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const FarmManagementScreen(),
                                    ),
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Manage farm'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (farms.length > 1)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showFarmSwitcher(
                                    context,
                                    farms,
                                    farm.id,
                                  ),
                                  icon: const Icon(Icons.swap_horiz),
                                  label: const Text('Switch farm'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Viewing ' +
                                  (farm.name.isEmpty ? 'Unnamed farm' : farm.name) +
                                  ' • Farm ' +
                                  '${farms.indexOf(farm) + 1} of ${farms.length}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          const SizedBox(height: 14),
                          Container(
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(
                               color: Theme.of(context).colorScheme.surfaceContainerHighest,
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     CircleAvatar(
                                       radius: 24,
                                       backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                       child: Icon(Icons.water_drop_outlined, color: Theme.of(context).colorScheme.onSecondaryContainer),
                                     ),
                                     const SizedBox(width: 12),
                                     Expanded(
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text(
                                             'Demo soil moisture sensor',
                                             style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                           ),
                                           const SizedBox(height: 4),
                                           Text(
                                             'Only soil moisture is simulated. Temperature, humidity and rainfall come from the weather API.',
                                             style: Theme.of(context).textTheme.bodySmall,
                                           ),
                                         ],
                                       ),
                                     ),
                                   ],
                                 ),
                                 const SizedBox(height: 10),
                                 Wrap(
                                   spacing: 12,
                                   runSpacing: 8,
                                   crossAxisAlignment: WrapCrossAlignment.center,
                                   children: [
                                     const Text('Soil condition', style: TextStyle(fontWeight: FontWeight.w600)),
                                     DropdownButtonHideUnderline(
                                       child: DropdownButton<String>(
                                         value: _demoPreset,
                                         isDense: true,
                                         items: const [
                                           DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                                           DropdownMenuItem(value: 'Dry soil', child: Text('Dry soil')),
                                           DropdownMenuItem(value: 'Wet soil', child: Text('Wet soil')),
                                         ],
                                         onChanged: (value) {
                                           if (value != null) setState(() => _demoPreset = value);
                                         },
                                       ),
                                     ),
                                   ],
                                 ),
                                 const SizedBox(height: 10),
                                 Wrap(
                                   spacing: 8,
                                   runSpacing: 8,
                                   children: [
                                     FilledButton(
                                       onPressed: _generateDemoReading,
                                       child: const Text('Generate soil data'),
                                     ),
                                     OutlinedButton(
                                       onPressed: () => _testDemoBackend(context, ref),
                                       child: const Text('Test API'),
                                     ),
                                   ],
                                 ),
                               ],
                             ),
                           ),
                           const SizedBox(height: 10),
                           _buildSyncBanner(context, farmDevices),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                             builder: (context, constraints) {
                               final tileWidth = constraints.maxWidth < 520
                                   ? (constraints.maxWidth - 10) / 2
                                   : (constraints.maxWidth - 20) / 3;
                               return Wrap(
                                 spacing: 10,
                                 runSpacing: 10,
                                 children: [
                                   SizedBox(
                                     width: tileWidth,
                                     child: _OverviewTile(
                                       icon: Icons.square_foot_outlined,
                                       label: 'Farm size',
                                       value: '${farm.sizeAcres.toStringAsFixed(1)} acres',
                                     ),
                                   ),
                                   SizedBox(
                                     width: tileWidth,
                                     child: _OverviewTile(
                                       icon: Icons.water_drop_outlined,
                                       label: 'Water',
                                       value: farm.waterSource,
                                     ),
                                   ),
                                   SizedBox(
                                     width: tileWidth,
                                     child: _OverviewTile(
                                       icon: Icons.water_outlined,
                                       label: 'Irrigation',
                                       value: farm.irrigationMethod,
                                     ),
                                   ),
                                 ],
                               );
                             },
                           ),
                           const SizedBox(height: 12),
                           Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                child: Icon(
                                  Icons.eco_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                                ),
                              ),
                              title: const Text(
                                'Crop growth stage',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                farm.growthStageLabel == null
                                    ? 'Planting date not available'
                                    : farm.growthStageLabel! + ' • ' +
                                      farm.cropAgeDays.toString() + ' days (' +
                                      farm.cropAgeYears!.toStringAsFixed(1) + ' years)',
                              ),
                              trailing: const Icon(Icons.auto_graph_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildCropHealthSummary(context, farmDevices, agg, alerts, irrigationDecision),
                          const SizedBox(height: 10),
                          _buildMlPredictionCard(context),
                          const SizedBox(height: 10),
                          Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.sensors_outlined),
                              ),
                              title: const Text('Device status', style: TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(_deviceStatusSummary(farmDevices)),
                              trailing: _statusChip(context, farmDevices),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DeviceManagementScreen()),
                              ),
                            ),
                          ),
                          if (irrigationDecision != null) ...[
                            Card(
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: irrigationDecision.irrigationRecommended
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    irrigationDecision.irrigationRecommended
                                        ? Icons.water_drop_outlined
                                        : Icons.water_drop_outlined,
                                  ),
                                ),
                                title: Text(
                                  irrigationDecision.irrigationRecommended
                                      ? 'Irrigation recommended'
                                      : 'No irrigation recommended',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  irrigationDecision.reason,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                children: [
                                  ListTile(
                                    title: Text(
                                      'Decision strength: ' +
                                          irrigationDecision.decisionStrength +
                                          ' (' +
                                          (irrigationDecision.confidence * 100)
                                              .round()
                                              .toString() +
                                          '%)',
                                    ),
                                    subtitle: Text(
                                      irrigationDecision.irrigationRecommended
                                          ? 'Suggested runtime: ' +
                                              irrigationDecision.suggestedDuration
                                                  .inMinutes
                                                  .toString() +
                                              ' minutes'
                                          : 'Suggested runtime: 0 minutes',
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: irrigationDecision.factors
                                          .map((factor) => Chip(label: Text(factor)))
                                          .toList(),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                                    child: Text(
                                      'Mode: Recommendation only. No pump command is issued from this dashboard card.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Text(
                                'Farm conditions',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const Spacer(),
                              Text(
                                '${farmDevices.length} device${farmDevices.length == 1 ? '' : 's'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.12,
                            children: [
                              _MetricCard(
                                icon: Icons.water_drop,
                                label: 'Soil moisture',
                                value: agg.soilMoisture == null
                                    ? '-'
                                    : '${agg.soilMoisture!.toStringAsFixed(1)}%',
                                unit: 'Moisture level',
                                warn: agg.soilMoisture != null &&
                                    (agg.soilMoisture! < 20 ||
                                        agg.soilMoisture! > 85),
                              ),
                              _MetricCard(
                                icon: Icons.thermostat,
                                label: 'Temperature',
                                value: agg.temperature == null
                                    ? '-'
                                    : '${agg.temperature!.toStringAsFixed(1)} C',
                                unit: 'Air temperature',
                                warn: agg.temperature != null &&
                                    (agg.temperature! < 10 ||
                                        agg.temperature! > 42),
                              ),
                              _MetricCard(
                                icon: Icons.cloud_outlined,
                                label: 'Humidity',
                                value: agg.humidity == null
                                    ? '-'
                                    : '${agg.humidity!.toStringAsFixed(1)}%',
                                unit: 'Relative humidity',
                              ),
                              _MetricCard(
                                icon: Icons.waterfall_chart,
                                label: 'Rainfall',
                                value: agg.rainfall == null
                                    ? '-'
                                    : '${agg.rainfall!.toStringAsFixed(1)} mm',
                                unit: 'Current rainfall',
                                warn: agg.rainfall != null &&
                                    agg.rainfall! > 150,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_demoReading != null)
                            Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  child: const Icon(Icons.water_drop_outlined),
                                ),
                                title: const Text(
                                  'Demo irrigation recommendation',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  _demoRecommendation(_demoReading!),
                                ),
                              ),
                            ),
                          if (_demoReading != null) const SizedBox(height: 10),
                          Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                child: Icon(
                                  farmDevices.isEmpty
                                      ? Icons.water_drop_outlined
                                      : Icons.auto_awesome_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                                ),
                              ),
                              title: const Text(
                                'Irrigation assistant',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  agg.hasReading
                                      ? 'Soil moisture uses the simulated sensor; temperature, humidity and rainfall use weather data.'
                                      : 'Soil moisture is simulated for now. Add a sensor for live soil readings.',
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: alerts.isEmpty
                                    ? Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                    : Theme.of(context)
                                        .colorScheme
                                        .errorContainer,
                                child: Icon(
                                  alerts.isEmpty
                                      ? Icons.check_circle_outline
                                      : Icons.warning_amber_rounded,
                                  color: alerts.isEmpty
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                ),
                              ),
                              title: Text(
                                alerts.isEmpty
                                    ? 'All farm conditions look normal'
                                    : '${alerts.length} active alert${alerts.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                alerts.isEmpty
                                    ? 'We will show warnings here when sensor data is available.'
                                    : 'Tap to view details',
                              ),
                              children: alerts.isEmpty
                                  ? const []
                                  : alerts
                                      .map(
                                        (a) => ListTile(
                                          leading: Icon(
                                            a.severity.icon,
                                            color: a.severity.color,
                                          ),
                                          title: Text(a.title),
                                          subtitle: Text(a.message),
                                          dense: true,
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Quick actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ActionChip(avatar: const Icon(Icons.refresh, size: 18), label: Text(_syncing ? 'Syncing...' : 'Sync now'), onPressed: _syncing ? null : () => _refreshDashboard(uid)),
                                      ActionChip(avatar: const Icon(Icons.agriculture_outlined, size: 18), label: const Text('Manage farm'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmManagementScreen()))),
                                      ActionChip(avatar: const Icon(Icons.sensors_outlined, size: 18), label: const Text('Manage devices'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceManagementScreen()))),
                                      ActionChip(avatar: const Icon(Icons.notifications_outlined, size: 18), label: const Text('View alerts'), onPressed: () => _showAlertsSheet(context, ref, uid, _selectedFarmId)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: const Icon(Icons.history),
                              ),
                              title: const Text(
                                'Recent activity',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(_recentActivitySummary(farmDevices, irrigationDecision)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildAppDrawerForRoute(
    BuildContext context,
    String farmerName, {
    String? farmId,
    String? selectedRoute,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final onFarm = farmId != null;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              color: scheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: scheme.onPrimary,
                    child: Icon(
                      Icons.agriculture_rounded,
                      color: scheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ArecaSmart',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    farmerName,
                    style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _drawerItem(
                    context,
                    Icons.dashboard_outlined,
                    'My farms',
                    () => context.go('/dashboard'),
                    selected: selectedRoute == '/dashboard',
                  ),
                  if (onFarm)
                    _drawerItem(
                      context,
                      Icons.agriculture_outlined,
                      'Farm overview',
                      () => context.go('/farm/$farmId'),
                      selected: selectedRoute == 'farm',
                    ),
                  _drawerItem(
                    context,
                    Icons.sensors_outlined,
                    'Devices',
                    () => context.go('/devices'),
                    selected: selectedRoute == '/devices',
                  ),
                  _drawerItem(
                    context,
                    Icons.notifications_none_rounded,
                    'Alerts',
                    () => _showAlertsSheet(
                      context,
                      ref,
                      ref.read(authControllerProvider).user?.uid,
                      farmId,
                    ),
                    selected: selectedRoute == 'alerts',
                  ),
                  _drawerItem(
                    context,
                    Icons.person_outline_rounded,
                    'Profile',
                    () => context.go('/profile'),
                    selected: selectedRoute == '/profile',
                  ),
                  _drawerItem(
                    context,
                    Icons.settings_outlined,
                    'Farm management',
                    () => context.go('/farms'),
                    selected: selectedRoute == '/farms',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _drawerItem(
              context,
              Icons.logout_rounded,
              'Sign out',
              () => ref.read(authControllerProvider.notifier).logout(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard(BuildContext context, FarmModel farm) {
    final scheme = Theme.of(context).colorScheme;
    if (_weatherLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Expanded(child: Text('Loading weather for the selected farm...')),
            ],
          ),
        ),
      );
    }
    if (_weatherError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_outlined, color: scheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Weather unavailable', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_weatherError!),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _loadWeatherForFarm(farm, forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final weather = _weather;
    if (weather == null) return const SizedBox.shrink();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.cloud_outlined, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Weather & irrigation inputs', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        '${weather.locationName} • ${weather.weatherDescription}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh weather',
                  onPressed: () => _loadWeatherForFarm(farm, forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 520
                    ? (constraints.maxWidth - 10) / 2
                    : (constraints.maxWidth - 20) / 3;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _weatherMetric(context, width, Icons.thermostat, 'Temperature',
                        weather.temperature == null ? '—' : '${weather.temperature!.toStringAsFixed(1)} °C'),
                    _weatherMetric(context, width, Icons.water_drop_outlined, 'Humidity',
                        weather.humidity == null ? '—' : '${weather.humidity!.toStringAsFixed(0)}%'),
                    _weatherMetric(context, width, Icons.umbrella_outlined, 'Next 24h rain',
                        '${weather.next24hPrecipitationMm.toStringAsFixed(1)} mm'),
                    _weatherMetric(context, width, Icons.cloud_outlined, 'Rain probability',
                        '${weather.next24hPrecipitationProbability.toStringAsFixed(0)}%'),
                    _weatherMetric(context, width, Icons.wb_sunny_outlined, 'Next 24h ET₀',
                        '${weather.next24hEt0Mm.toStringAsFixed(1)} mm'),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            const Text('3-day forecast', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: weather.forecast.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final day = weather.forecast[index];
                  return Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day.date.length >= 10 ? day.date.substring(5) : day.date,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('${day.temperatureMin?.toStringAsFixed(0) ?? '—'}–${day.temperatureMax?.toStringAsFixed(0) ?? '—'} °C'),
                        Text('${day.precipitationMm?.toStringAsFixed(1) ?? '—'} mm rain'),
                        Text('${day.precipitationProbability?.toStringAsFixed(0) ?? '—'}% chance'),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Weather data: Open-Meteo • Location resolved from farmer-entered ${farm.village}, ${farm.taluk}, ${farm.district}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherMetric(
    BuildContext context,
    double width,
    IconData icon,
    String label,
    String value,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBanner(BuildContext context, List<DeviceModel> devices) {
    final scheme = Theme.of(context).colorScheme;
    final hasOffline = devices.any((d) =>
        d.connectionState == DeviceConnectionState.offline ||
        d.connectionState == DeviceConnectionState.stale);
    final latest = devices
        .map((d) => d.latestReading?.timestamp)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (current, value) =>
            current == null || value.isAfter(current) ? value : current);
    final stale = latest != null &&
        DateTime.now().difference(latest) > const Duration(minutes: 10);
    final message = devices.isEmpty
        ? 'No sensor device is assigned to this farm.'
        : stale
            ? 'Sensor readings are stale. Showing the last available values.'
            : hasOffline
                ? 'Some device data is offline or stale.'
                : 'Dashboard is synchronized with the selected farm.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (devices.isEmpty || stale || hasOffline)
            ? scheme.tertiaryContainer
            : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(devices.isEmpty || stale || hasOffline
              ? Icons.sync_problem_outlined
              : Icons.sync_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          if (_lastSyncAt != null)
            Text(_timeAgo(_lastSyncAt!), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildCropHealthSummary(
    BuildContext context,
    List<DeviceModel> devices,
    _ReadingSummary agg,
    List<_FarmAlert> alerts,
    IrrigationDecision? irrigationDecision,
  ) {
    final critical = alerts.where((a) => a.severity == _AlertSeverity.critical).length;
    final warning = alerts.where((a) => a.severity == _AlertSeverity.warning).length;
    final health = critical > 0
        ? 'Needs attention'
        : warning > 0
            ? 'Watch closely'
            : agg.hasReading
                ? 'Stable'
                : 'Waiting for sensor data';
    final detail = critical > 0
        ? '${critical} critical alert${critical == 1 ? '' : 's'} need attention.'
        : warning > 0
            ? '${warning} warning${warning == 1 ? '' : 's'} detected. Review the active alerts.'
            : !agg.hasReading
                ? 'No current sensor reading is available for this farm.'
                : irrigationDecision?.irrigationRecommended == true
                    ? 'Conditions are driving an irrigation recommendation.'
                    : 'No major condition alert is active.';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(Icons.eco_outlined, color: Theme.of(context).colorScheme.onSecondaryContainer),
        ),
        title: const Text('Crop health summary', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detail),
        trailing: Text(health, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  String _deviceStatusSummary(List<DeviceModel> devices) {
    if (devices.isEmpty) return 'No device assigned to this farm.';
    final online = devices.where((d) => d.connectionState == DeviceConnectionState.online).length;
    final stale = devices.where((d) => d.connectionState == DeviceConnectionState.stale).length;
    final offline = devices.where((d) => d.connectionState == DeviceConnectionState.offline).length;
    return '${online} online • ${stale} stale • ${offline} offline';
  }

  String _recentActivitySummary(
    List<DeviceModel> devices,
    IrrigationDecision? irrigationDecision,
  ) {
    final latest = devices
        .map((d) => d.latestReading?.timestamp)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (current, value) =>
            current == null || value.isAfter(current) ? value : current);
    if (irrigationDecision != null) {
      return 'Latest irrigation assessment: ${irrigationDecision.irrigationRecommended ? 'irrigation recommended' : 'no irrigation recommended'} • ${_timeAgo(irrigationDecision.createdAt)}.';
    }
    if (latest != null) return 'Latest sensor reading received ${_timeAgo(latest)}.';
    return 'No sensor activity has been recorded for this farm yet.';
  }

  Widget _statusChip(BuildContext context, List<DeviceModel> devices) {
    final online = devices.where((d) =>
        d.connectionState == DeviceConnectionState.online).length;
    final total = devices.length;
    final Color color;
    final String text;
    if (total == 0) {
      color = Colors.grey;
      text = 'No devices';
    } else if (online == total) {
      color = Colors.green;
      text = 'All online';
    } else if (online > 0) {
      color = Colors.orange;
      text = '$online/$total online';
    } else {
      color = Colors.red;
      text = 'All offline';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  _ReadingSummary _aggregate(List<DeviceModel> devices) {
    final readings =
        devices.map((d) => d.latestReading).whereType<SensorReading>().toList();
    if (readings.isEmpty) return const _ReadingSummary();
    final soilValues =
        readings.map((reading) => reading.soilMoisture).whereType<double>().toList();

    return _ReadingSummary(
      soilMoisture: soilValues.isEmpty
          ? null
          : soilValues.reduce((a, b) => a + b) / soilValues.length,
      count: readings.length,
    );
  }

  List<_FarmAlert> _generateAlerts(List<DeviceModel> devices) {
    final alerts = <_FarmAlert>[];
    for (final d in devices) {
      if (d.connectionState == DeviceConnectionState.offline) {
        alerts.add(_FarmAlert(
          severity: _AlertSeverity.warning,
          title: '${d.name} is offline',
          message:
              'Last seen ${_timeAgo(d.lastSeen)}. Check device power and connectivity.',
        ));
      } else if (d.connectionState == DeviceConnectionState.stale) {
        alerts.add(_FarmAlert(
          severity: _AlertSeverity.info,
          title: '${d.name} data is stale',
          message: 'No data in last hour.',
        ));
      }
      final r = d.latestReading;
      if (r != null) {
        if (r.soilMoisture != null && r.soilMoisture! < 20) {
          alerts.add(_FarmAlert(
            severity: _AlertSeverity.critical,
            title: 'Low soil moisture on ${d.name}',
            message:
                '${r.soilMoisture!.toStringAsFixed(1)}% - irrigation recommended.',
          ));
        }
        if (r.soilMoisture != null && r.soilMoisture! > 90) {
          alerts.add(_FarmAlert(
            severity: _AlertSeverity.warning,
            title: 'High soil moisture on ${d.name}',
            message:
                '${r.soilMoisture!.toStringAsFixed(1)}% - risk of waterlogging.',
          ));
        }

      }
    }
    return alerts;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _showAlertsSheet(
      BuildContext context, WidgetRef ref, String? uid, String? selectedFarmId) async {
    if (uid == null) return;
    final farms = await ref.read(farmRepositoryProvider).getFarms(uid);
    final devices = await ref.read(deviceRepositoryProvider).getDevices(uid);
    final selectedFarmIdResolved = farms.isEmpty
        ? null
        : farms.any((farm) => farm.id == selectedFarmId)
            ? selectedFarmId
            : farms.first.id;
    final farmDevices = selectedFarmIdResolved == null
        ? devices
        : devices.where((d) => d.farmId == selectedFarmIdResolved).toList();
    final alerts = _generateAlerts(farmDevices);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Text('Alerts',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const Spacer(),
                  Chip(
                    label: Text('${alerts.length}'),
                    backgroundColor: alerts.isEmpty
                        ? Colors.grey.withValues(alpha: 0.2)
                        : (alerts.any((a) =>
                                a.severity == _AlertSeverity.critical)
                            ? Colors.red.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              fit: FlexFit.loose,
              child: alerts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 56, color: Colors.green),
                          SizedBox(height: 12),
                          Text(
                            'All clear! No active alerts.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: alerts.length,
                      itemBuilder: (_, i) {
                        final a = alerts[i];
                        return ListTile(
                          leading: Icon(a.severity.icon,
                              color: a.severity.color),
                          title: Text(a.title),
                          subtitle: Text(a.message),
                          isThreeLine: a.message.length > 60,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IrrigationDecision? _buildIrrigationDecision(
    FarmModel farm,
    _ReadingSummary agg,
    WeatherData? weather,
  ) {
    final stage = farm.growthStage;
    final ageDays = farm.cropAgeDays;
    if (stage == null || ageDays == null || weather == null) return null;

    final weatherContext = weather.next24hPrecipitationMm >= 8
        ? 'heavy rain forecast'
        : weather.next24hPrecipitationProbability >= 70
            ? 'rain likely'
            : weather.temperature != null && weather.temperature! >= 36
                ? 'hot'
                : 'normal';

    return IrrigationDecisionEngine().decide(
      input: IrrigationInput(
        soilMoisture: agg.soilMoisture,
        cropAgeDays: ageDays,
        growthStage: stage,
        temperature: weather.temperature,
        humidity: weather.humidity,
        rainfall: weather.precipitationMm,
        weatherContext: weatherContext,
        forecastPrecipitation24h: weather.next24hPrecipitationMm,
        forecastPrecipitationProbability24h: weather.next24hPrecipitationProbability,
        forecastEt024h: weather.next24hEt0Mm,
        recentIrrigation: RecentIrrigation(),
        observedAt: DateTime.now(),
      ),
      mode: IrrigationMode.recommendationOnly,
    );
  }

  String _decisionKey(
    FarmModel farm,
    _ReadingSummary agg,
    IrrigationDecision decision,
  ) {
    return [
      farm.id,
      agg.soilMoisture,
      agg.temperature,
      agg.humidity,
      agg.rainfall,
      decision.irrigationRecommended,
      decision.suggestedDuration.inSeconds,
    ].join('|');
  }

  Future<void> _recordDashboardRecommendation(
    IrrigationDecision decision,
    String auditKey,
    String uid,
  ) async {
    if (!mounted) return;
    try {
      await FirestoreIrrigationAuditLog(
        db: FirebaseFirestore.instance,
        userId: uid,
      ).record(
        IrrigationAuditRecord(
          id: 'recommendation_' + decision.decisionId,
          type: IrrigationAuditType.recommendation,
          decisionId: decision.decisionId,
          action: 'recommendation',
          status: decision.irrigationRecommended
              ? 'recommended'
              : 'not_recommended',
          reason: decision.reason,
          timestamp: decision.createdAt,
          details: decision.toMap(),
        ),
      );
      _decisionAuditKey = auditKey;
    } catch (_) {
      // The decision remains visible locally even if audit persistence is offline.
    }
  }

  Future<void> _showFarmSwitcher(
    BuildContext context,
    List<FarmModel> farms,
    String currentFarmId,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Switch farm',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...farms.map(
                (item) => ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      item.id == currentFarmId
                          ? Icons.check
                          : Icons.agriculture_outlined,
                    ),
                  ),
                  title: Text(
                    item.name.isEmpty ? 'Unnamed farm' : item.name,
                  ),
                  subtitle: item.location.isEmpty ? null : Text(item.location),
                  trailing: item.id == currentFarmId
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(item.id),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted && selected != currentFarmId) {
      setState(() => _selectedFarmId = selected);
    }
  }
  String _demoRecommendation(SensorReading reading) {
    final moisture = reading.soilMoisture ?? 0;
    if (moisture < 20) {
      return 'Irrigation recommended in this demo scenario. Soil moisture is low.';
    }
    if (moisture > 80 || (reading.rainfall ?? 0) > 25) {
      return 'Irrigation can be delayed in this demo scenario because moisture or rainfall is high.';
    }
    return 'No immediate irrigation recommended in this demo scenario.';
  }

  List<_FarmAlert> _generateAlertsForFarm(
    List<DeviceModel> farmDevices,
    SensorReading? demoReading,
    WeatherData? weather,
  ) {
    if (demoReading != null) {
      final alerts = <_FarmAlert>[];
      final moisture = demoReading.soilMoisture;
      if (moisture != null && moisture < 20) {
        alerts.add(_FarmAlert(
          title: 'Low soil moisture',
          message: 'Simulated soil moisture is below 20%.',
          severity: _AlertSeverity.warning,
        ));
      }
      if (weather?.temperature != null && weather!.temperature! > 40) {
        alerts.add(_FarmAlert(
          title: 'High temperature',
          message: 'Current weather temperature is above 40 °C.',
          severity: _AlertSeverity.warning,
        ));
      }
      if (weather != null && weather.next24hPrecipitationMm > 25) {
        alerts.add(_FarmAlert(
          title: 'Heavy rain forecast',
          message: 'More than 25 mm of precipitation is forecast in the next 24 hours.',
          severity: _AlertSeverity.info,
        ));
      }
      return alerts;
    }

    return _generateAlerts(farmDevices);
  }

  _ReadingSummary _aggregateReading(SensorReading reading) {
    return _ReadingSummary(
      soilMoisture: reading.soilMoisture,
      temperature: reading.temperature,
      humidity: reading.humidity,
      rainfall: reading.rainfall,
    );
  }

  Widget _syncError(
    BuildContext context,
    String title,
    String subtitle,
    VoidCallback onRetry,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry sync'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.agriculture, size: 56),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/farms'),
              icon: const Icon(Icons.add_business),
              label: const Text('Manage farms'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingSummary {
  final double? soilMoisture;
  final double? temperature;
  final double? humidity;
  final double? rainfall;
  final int count;

  const _ReadingSummary({
    this.soilMoisture,
    this.temperature,
    this.humidity,
    this.rainfall,
    this.count = 0,
  });

  bool get hasReading => count > 0;
}

enum _AlertSeverity { critical, warning, info }

extension _AlertSeverityX on _AlertSeverity {
  IconData get icon {
    switch (this) {
      case _AlertSeverity.critical:
        return Icons.error;
      case _AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case _AlertSeverity.info:
        return Icons.info;
    }
  }

  Color get color {
    switch (this) {
      case _AlertSeverity.critical:
        return Colors.red;
      case _AlertSeverity.warning:
        return Colors.orange;
      case _AlertSeverity.info:
        return Colors.blue;
    }
  }
}

class _FarmAlert {
  final _AlertSeverity severity;
  final String title;
  final String message;

  const _FarmAlert({
    required this.severity,
    required this.title,
    required this.message,
  });
}

class _OverviewTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool warn;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = warn ? scheme.error : scheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warn
            ? scheme.errorContainer.withValues(alpha: 0.55)
            : scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: warn ? scheme.error.withValues(alpha: 0.25) : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: scheme.surface,
            child: Icon(icon, color: accent),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            unit,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

