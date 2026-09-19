import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/device/device_model.dart';
import '../../../models/farm/farm_model.dart';
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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

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

  SensorReading _presetReading(String preset) {
    final now = DateTime.now();
    switch (preset) {
      case 'Dry soil':
        return SensorReading(
          soilMoisture: 12,
          temperature: 33,
          humidity: 48,
          rainfall: 0,
          timestamp: now,
        );
      case 'Hot day':
        return SensorReading(
          soilMoisture: 24,
          temperature: 41,
          humidity: 42,
          rainfall: 0,
          timestamp: now,
        );
      case 'Heavy rain':
        return SensorReading(
          soilMoisture: 82,
          temperature: 27,
          humidity: 86,
          rainfall: 38,
          timestamp: now,
        );
      default:
        return ref.read(simulatedSensorProvider).generateReading();
    }
  }

  void _generateDemoReading() {
    setState(() {
      _demoReading = _presetReading(_demoPreset);
    });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ArecaSmart'),
        actions: [
          IconButton(
            onPressed: () => _showAlertsSheet(context, ref, uid),
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Alerts',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FarmManagementScreen(),
              ),
            ),
            icon: const Icon(Icons.agriculture),
            tooltip: 'Farms',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DeviceManagementScreen(),
              ),
            ),
            icon: const Icon(Icons.sensors),
            tooltip: 'Devices',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileEditScreen(),
              ),
            ),
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in.'))
          : FutureBuilder<List<FarmModel>>(
              future: ref.read(farmRepositoryProvider).getFarms(uid),
              builder: (context, farmsSnapshot) {
                if (farmsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (farmsSnapshot.hasError) {
                  return _empty(
                    context,
                    'Could not load farms',
                    'Please try again.',
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

                final selectedId = _selectedFarmId;
                final farm = farms.firstWhere(
                  (item) => item.id == selectedId,
                  orElse: () => farms.first,
                );
                final cropAgeDays = farm.cropAgeDays;
                final cropAgeYears = farm.cropAgeYears;
                final growthStage = farm.growthStageLabel;
                final plantingDate = farm.plantingDate?.toIso8601String();

                if (_selectedFarmId != farm.id ||
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
                      });
                    }
                  });
                }
                return FutureBuilder<List<DeviceModel>>(
                  future: ref
                      .read(deviceRepositoryProvider)
                      .getDevices(uid),
                  builder: (context, deviceSnapshot) {
                    if (deviceSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (deviceSnapshot.hasError) {
                      return _empty(
                        context,
                        'Could not load devices',
                        'Please try again.',
                      );
                    }

                    final devices = deviceSnapshot.data ?? [];
                    final farmDevices =
                        devices.where((d) => d.farmId == farm.id).toList();
                    final alerts = _demoReading == null
                        ? _generateAlerts(farmDevices)
                        : _generateAlertsFromReading(_demoReading!);
                    final agg = _demoReading == null
                        ? _aggregate(farmDevices)
                        : _aggregateReading(_demoReading!);
                    final irrigationDecision =
                        _buildIrrigationDecision(farm, agg);
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
                      onRefresh: () async {
                        setState(() {});
                      },
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  child: Icon(
                                    Icons.science_outlined,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Demo sensor mode',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _demoPreset,
                                          isDense: true,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Normal',
                                              child: Text('Normal'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Dry soil',
                                              child: Text('Dry soil'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Hot day',
                                              child: Text('Hot day'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Heavy rain',
                                              child: Text('Heavy rain'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() => _demoPreset = value);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Simulated readings only - physical sensors are not connected.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  children: [
                                    SizedBox(
                                      width: 92,
                                      child: FilledButton(
                                        onPressed: _generateDemoReading,
                                        child: const Text('Generate'),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: 92,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _testDemoBackend(context, ref),
                                        child: const Text('Test ML'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _OverviewTile(
                                  icon: Icons.square_foot_outlined,
                                  label: 'Farm size',
                                  value: '${farm.sizeAcres.toStringAsFixed(1)} acres',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _OverviewTile(
                                  icon: Icons.water_drop_outlined,
                                  label: 'Water',
                                  value: farm.waterSource,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _OverviewTile(
                                  icon: Icons.water_outlined,
                                  label: 'Irrigation',
                                  value: farm.irrigationMethod,
                                ),
                              ),
                            ],
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
                          ),                          if (irrigationDecision != null) ...[
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
                                unit: 'Recorded rainfall',
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
                                  farmDevices.isEmpty
                                      ? 'Add a sensor to receive live irrigation insights.'
                                      : agg.hasReading
                                          ? 'Sensor data received. ML prediction is not connected yet.'
                                          : 'Sensors are online and waiting for the first reading.',
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
                              subtitle: const Text(
                                'No activity events have been recorded yet.',
                              ),
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
    double? avg(
        double? Function(SensorReading) acc, List<SensorReading> list) {
      final vals = list.map(acc).whereType<double>().toList();
      if (vals.isEmpty) return null;
      return vals.reduce((a, b) => a + b) / vals.length;
    }

    return _ReadingSummary(
      soilMoisture: avg((r) => r.soilMoisture, readings),
      temperature: avg((r) => r.temperature, readings),
      humidity: avg((r) => r.humidity, readings),
      rainfall: avg((r) => r.rainfall, readings),
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
        if (r.temperature != null && r.temperature! > 40) {
          alerts.add(_FarmAlert(
            severity: _AlertSeverity.warning,
            title: 'High temperature (${r.temperature!.toStringAsFixed(1)} C)',
            message: 'Monitor crop stress on ${d.name}.',
          ));
        }
        if (r.rainfall != null && r.rainfall! > 100) {
          alerts.add(_FarmAlert(
            severity: _AlertSeverity.info,
            title: 'Heavy rainfall recorded',
            message:
                '${r.rainfall!.toStringAsFixed(0)} mm on ${d.name}. Check drainage.',
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
      BuildContext context, WidgetRef ref, String? uid) async {
    if (uid == null) return;
    final farms = await ref.read(farmRepositoryProvider).getFarms(uid);
    final devices = await ref.read(deviceRepositoryProvider).getDevices(uid);
    final farmDevices = farms.isEmpty
        ? devices
        : devices.where((d) => d.farmId == farms.first.id).toList();
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
  ) {
    final stage = farm.growthStage;
    final ageDays = farm.cropAgeDays;
    if (stage == null || ageDays == null) return null;

    final weather = (agg.rainfall ?? 0) >= 20
        ? 'heavy rain'
        : (agg.temperature ?? 0) >= 36
            ? 'hot'
            : 'normal';

    return const IrrigationDecisionEngine().decide(
      input: IrrigationInput(
        soilMoisture: agg.soilMoisture,
        cropAgeDays: ageDays,
        growthStage: stage,
        temperature: agg.temperature,
        humidity: agg.humidity,
        rainfall: agg.rainfall,
        weatherContext: weather,
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

  List<_FarmAlert> _generateAlertsFromReading(SensorReading reading) {
    final alerts = <_FarmAlert>[];
    final moisture = reading.soilMoisture;
    final temperature = reading.temperature;
    final rainfall = reading.rainfall;
    if (moisture != null && moisture < 20) {
      alerts.add(_FarmAlert(
        title: 'Low soil moisture',
        message: 'Demo reading is below 20%.',
        severity: _AlertSeverity.warning,
      ));
    }
    if (temperature != null && temperature > 40) {
      alerts.add(_FarmAlert(
        title: 'High temperature',
        message: 'Demo temperature is above 40 C.',
        severity: _AlertSeverity.warning,
      ));
    }
    if (rainfall != null && rainfall > 25) {
      alerts.add(_FarmAlert(
        title: 'Heavy rainfall',
        message: 'Demo rainfall is above 25 mm.',
        severity: _AlertSeverity.info,
      ));
    }
    return alerts;
  }

  _ReadingSummary _aggregateReading(SensorReading reading) {
    return _ReadingSummary(
      soilMoisture: reading.soilMoisture,
      temperature: reading.temperature,
      humidity: reading.humidity,
      rainfall: reading.rainfall,
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

