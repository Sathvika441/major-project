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
  final ScrollController _workspaceScrollController = ScrollController();

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

    FocusScope.of(context).unfocus();
    _preserveWorkspaceScroll(() {
      setState(() {
        _mlImage = file;
        _mlResult = null;
        _mlError = null;
        _mlUploading = false;
      });
    });
  }

  Future<void> _predictMlImage(BuildContext context) async {
    final file = _mlImage;
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) {
      setState(() => _mlError = 'Please upload an image before predicting.');
      return;
    }

    FocusScope.of(context).unfocus();
    _preserveWorkspaceScroll(() {
      setState(() {
        _mlResult = null;
        _mlError = null;
        _mlUploading = true;
      });
    });

    try {
      final result = await ref.read(backendApiProvider).predictImage(
        bytes,
        filename: file.name,
      );
      if (!mounted) return;
      _preserveWorkspaceScroll(() {
        setState(() {
          _mlResult = result;
          _mlUploading = false;
        });
      });
    } on BackendApiException catch (e) {
      if (!mounted) return;
      _preserveWorkspaceScroll(() {
        setState(() {
          _mlUploading = false;
          _mlError = e.message;
        });
      });
    } catch (_) {
      if (!mounted) return;
      _preserveWorkspaceScroll(() {
        setState(() {
          _mlUploading = false;
          _mlError =
              'Unexpected error while contacting the ML service. Please try again.';
        });
      });
    }
  }

  void _clearMlPrediction() {
    FocusScope.of(context).unfocus();
    _preserveWorkspaceScroll(() {
      setState(() {
        _mlImage = null;
        _mlResult = null;
        _mlError = null;
        _mlUploading = false;
      });
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

  @override
  void dispose() {
    _workspaceScrollController.dispose();
    super.dispose();
  }

  void _preserveWorkspaceScroll(VoidCallback update) {
    final controller = _workspaceScrollController;
    final offset = controller.hasClients ? controller.offset : 0.0;
    update();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      final target = offset.clamp(0.0, controller.position.maxScrollExtent);
      if ((controller.offset - target).abs() > 0.5) controller.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final user = ref.watch(authControllerProvider).user;
    final uid = user?.uid;

    final isFarmWorkspace = widget.initialFarmId != null;

    return AppNavigationScaffold(
      title: isFarmWorkspace ? 'Farm workspace' : 'My farms',
      showBackButton: isFarmWorkspace,
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
                      null,
                      _weather,
                    );
                    final sensorAgg = _aggregate(farmDevices);
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
                        key: const PageStorageKey<String>('farm-workspace'),
                        controller: _workspaceScrollController,
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
                                const SizedBox.shrink(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                           const SizedBox(height: 10),
