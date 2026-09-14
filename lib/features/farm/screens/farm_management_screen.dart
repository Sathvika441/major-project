import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/device/device_model.dart';
import '../../../models/farm/farm_model.dart';
import '../../../repositories/device/device_repository.dart';
import '../../../repositories/farm/farm_repository.dart';
import '../../auth/controllers/auth_controller.dart';

final selectedFarmProvider = StateProvider<String?>((ref) => null);

final farmsProvider = FutureProvider.autoDispose<List<FarmModel>>((ref) async {
  final userId = ref.watch(authControllerProvider).user?.uid;
  if (userId == null) return [];
  return ref.watch(farmRepositoryProvider).getFarms(userId);
});

class FarmManagementScreen extends ConsumerWidget {
  const FarmManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(farmsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Farm Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFarmDialog(context, ref),
        icon: const Icon(Icons.add_business),
        label: const Text('Add farm'),
      ),
      body: farms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load farms.\n$error'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('No farms yet. Add your first farm.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => _FarmTile(farm: items[index]),
          );
        },
      ),
    );
  }

  static Future<void> _showFarmDialog(
    BuildContext context,
    WidgetRef ref, {
    FarmModel? existing,
  }) async {
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?.name ?? '');
    final location = TextEditingController(text: existing?.location ?? '');
    final size = TextEditingController(
      text: existing != null ? existing.sizeAcres.toString() : '',
    );
    final water = TextEditingController(
      text: existing?.waterSource ?? 'Borewell',
    );
    final method = TextEditingController(
      text: existing?.irrigationMethod ?? 'Drip',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit farm' : 'Create farm'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Farm name'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: location,
                    decoration: const InputDecoration(labelText: 'Location'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: size,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Size (acres)',
                    ),
                    validator: (value) => double.tryParse(value ?? '') == null
                        ? 'Enter a valid size'
                        : null,
                  ),
                  TextFormField(
                    controller: water,
                    decoration: const InputDecoration(
                      labelText: 'Water source',
                    ),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: method,
                    decoration: const InputDecoration(
                      labelText: 'Irrigation method',
                    ),
                    validator: _required,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (isEdit)
              TextButton(
                onPressed: () async {
                  final user = ref.read(authControllerProvider).user;
                  if (user == null) return;
                  await ref
                      .read(farmRepositoryProvider)
                      .deactivateFarm(user.uid, existing.id);
                  ref.invalidate(farmsProvider);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    Navigator.pop(dialogContext);
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final user = ref.read(authControllerProvider).user;
                if (user == null) return;

                final farm = isEdit
                    ? existing.copyWith(
                        name: name.text.trim(),
                        location: location.text.trim(),
                        sizeAcres: double.parse(size.text),
                        waterSource: water.text.trim(),
                        irrigationMethod: method.text.trim(),
                        updatedAt: DateTime.now(),
                      )
                    : FarmModel(
                        id: 'farm_${DateTime.now().microsecondsSinceEpoch}',
                        userId: user.uid,
                        name: name.text.trim(),
                        location: location.text.trim(),
                        sizeAcres: double.parse(size.text),
                        waterSource: water.text.trim(),
                        irrigationMethod: method.text.trim(),
                        createdAt: DateTime.now(),
                      );

                await ref.read(farmRepositoryProvider).saveFarm(farm);

                ref.invalidate(farmsProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  static String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }
}

class _FarmTile extends ConsumerWidget {
  final FarmModel farm;

  const _FarmTile({required this.farm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.agriculture)),
        title: Text(farm.name),
        subtitle: Text(
          '${farm.location} • ${farm.sizeAcres} acres\n'
          '${farm.waterSource} • ${farm.irrigationMethod}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              onPressed: () => FarmManagementScreen._showFarmDialog(
                context,
                ref,
                existing: farm,
              ),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit farm',
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          ref.read(selectedFarmProvider.notifier).state = farm.id;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FarmDetailsScreen(farm: farm)),
          );
          ref.invalidate(farmsProvider);
        },
      ),
    );
  }
}

class FarmDetailsScreen extends ConsumerStatefulWidget {
  final FarmModel farm;

  const FarmDetailsScreen({super.key, required this.farm});

  @override
  ConsumerState<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends ConsumerState<FarmDetailsScreen> {
  late Future<List<DeviceModel>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final user = ref.read(authControllerProvider).user;
    _devicesFuture = user == null
        ? Future.value(<DeviceModel>[])
        : ref.read(deviceRepositoryProvider).getDevices(user.uid);
  }

  List<_LiveAlert> _alertsFor(List<DeviceModel> farmDevices) {
    final out = <_LiveAlert>[];
    for (final d in farmDevices) {
      if (d.connectionState == DeviceConnectionState.offline) {
        out.add(
          _LiveAlert(
            severity: _AlertLevel.critical,
            title: '${d.name} offline',
            message:
                'Last seen ${_ago(d.lastSeen)}. Power cycle or check network.',
          ),
        );
      } else if (d.connectionState == DeviceConnectionState.stale) {
        out.add(
          _LiveAlert(
            severity: _AlertLevel.warning,
            title: '${d.name} stale',
            message: 'No fresh data for over 1 hour.',
          ),
        );
      }
      final r = d.latestReading;
      if (r == null) continue;
      if (r.soilMoisture != null && r.soilMoisture! < 15) {
        out.add(
          _LiveAlert(
            severity: _AlertLevel.critical,
            title: 'Critical low moisture on ${d.name}',
            message:
                '${r.soilMoisture!.toStringAsFixed(1)}% — irrigate immediately.',
          ),
        );
      } else if (r.soilMoisture != null && r.soilMoisture! < 25) {
        out.add(
          _LiveAlert(
            severity: _AlertLevel.warning,
            title: 'Low moisture on ${d.name}',
            message:
                '${r.soilMoisture!.toStringAsFixed(1)}% — schedule irrigation.',
          ),
        );
      }
      if (r.soilMoisture != null && r.soilMoisture! > 92) {
        out.add(
          _LiveAlert(
            severity: _AlertLevel.warning,
            title: 'Waterlogging risk on ${d.name}',
            message:
                'Soil moisture ${r.soilMoisture!.toStringAsFixed(1)}% — pause irrigation.',
          ),
        );
      }
      if (r.temperature != null && r.temperature! > 42) {
        out.add(
          _LiveAlert(
            severity: _AlertLevel.warning,
            title: 'Heat stress warning',
            message:
                '${r.temperature!.toStringAsFixed(1)}°C on ${d.name} — consider shade/misting.',
          ),
        );
      }
      if (r.humidity != null && r.humidity! > 92) {
        out.add(
          _LiveAlert(
            severity: _AlertLevel.info,
            title: 'High humidity (${r.humidity!.toStringAsFixed(0)}%)',
            message: 'Monitor for fungal disease risk on ${d.name}.',
          ),
        );
      }
      if (r.rainfall != null && r.rainfall! > 120) {
        out.add(
          _LiveAlert(
            severity: _AlertLevel.info,
            title: 'Heavy rainfall: ${r.rainfall!.toStringAsFixed(0)}mm',
            message: 'Recorded by ${d.name}. Inspect drainage channels.',
          ),
        );
      }
    }
    return out;
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.farm.name),
        actions: [
          IconButton(
            onPressed: () => FarmManagementScreen._showFarmDialog(
              context,
              ref,
              existing: widget.farm,
            ),
            icon: const Icon(Icons.edit),
            tooltip: 'Edit farm',
          ),
          IconButton(
            onPressed: () {
              setState(() => _refresh());
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh live data',
          ),
        ],
      ),
      body: FutureBuilder<List<DeviceModel>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load live data.\n${snapshot.error}'),
            );
          }
          final devices = snapshot.data ?? [];
          final farmDevices = devices
              .where((d) => d.farmId == widget.farm.id)
              .toList();
          final alerts = _alertsFor(farmDevices);
          final agg = _aggregate(farmDevices);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _refresh());
              await _devicesFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.agriculture, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.farm.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            _StatusPill(devices: farmDevices),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.farm.location,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.farm.sizeAcres} acres • ${widget.farm.waterSource} • ${widget.farm.irrigationMethod}',
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Stat(
                              label: 'Sensors',
                              value: '${farmDevices.length}',
                              icon: Icons.sensors,
                            ),
                            _Stat(
                              label: 'Online',
                              value:
                                  '${farmDevices.where((d) => d.connectionState == DeviceConnectionState.online).length}',
                              icon: Icons.check_circle,
                              color: Colors.green,
                            ),
                            _Stat(
                              label: 'Alerts',
                              value: '${alerts.length}',
                              icon: Icons.notification_important,
                              color: alerts.isEmpty
                                  ? Colors.grey
                                  : (alerts.any(
                                          (a) =>
                                              a.severity ==
                                              _AlertLevel.critical,
                                        )
                                        ? Colors.red
                                        : Colors.orange),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Live sensor data (aggregated)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _LiveMetric(
                      icon: Icons.water_drop,
                      label: 'Soil moisture',
                      value: agg.moisture == null
                          ? 'No data'
                          : '${agg.moisture!.toStringAsFixed(1)} %',
                      status: _soilStatus(agg.moisture),
                    ),
                    _LiveMetric(
                      icon: Icons.thermostat,
                      label: 'Temperature',
                      value: agg.temp == null
                          ? 'No data'
                          : '${agg.temp!.toStringAsFixed(1)} °C',
                      status: _tempStatus(agg.temp),
                    ),
                    _LiveMetric(
                      icon: Icons.cloud,
                      label: 'Humidity',
                      value: agg.humidity == null
                          ? 'No data'
                          : '${agg.humidity!.toStringAsFixed(1)} %',
                      status: _humidityStatus(agg.humidity),
                    ),
                    _LiveMetric(
                      icon: Icons.water,
                      label: 'Rainfall (24h)',
                      value: agg.rain == null
                          ? 'No data'
                          : '${agg.rain!.toStringAsFixed(1)} mm',
                      status: _rainStatus(agg.rain),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      alerts.isEmpty
                          ? Icons.notifications_none
                          : Icons.notification_important,
                      color: alerts.isEmpty
                          ? Colors.grey
                          : (alerts.any(
                                  (a) => a.severity == _AlertLevel.critical,
                                )
                                ? Colors.red
                                : Colors.orange),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Active alerts (${alerts.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (alerts.isNotEmpty)
                      Text(
                        '${alerts.where((a) => a.severity == _AlertLevel.critical).length} critical',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (alerts.isEmpty)
                  Card(
                    color: Colors.green.withOpacity(0.06),
                    child: const ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('No active alerts'),
                      subtitle: Text(
                        'All monitored conditions within normal ranges.',
                      ),
                    ),
                  )
                else
                  ...alerts.map(
                    (a) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      color: a.severity.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: a.severity.color),
                      ),
                      child: ListTile(
                        leading: Icon(a.severity.icon, color: a.severity.color),
                        title: Text(
                          a.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(a.message),
                        isThreeLine: a.message.length > 60,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Text(
                  'Individual sensors',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (farmDevices.isEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.sensors_off),
                      title: const Text('No sensors assigned'),
                      subtitle: const Text(
                        'Assign devices from the Devices screen to see per-sensor live data here.',
                      ),
                    ),
                  )
                else
                  ...farmDevices.map(
                    (d) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  d.connectionState ==
                                          DeviceConnectionState.online
                                      ? Icons.check_circle
                                      : d.connectionState ==
                                            DeviceConnectionState.stale
                                      ? Icons.schedule
                                      : Icons.offline_bolt,
                                  color:
                                      d.connectionState ==
                                          DeviceConnectionState.online
                                      ? Colors.green
                                      : d.connectionState ==
                                            DeviceConnectionState.stale
                                      ? Colors.orange
                                      : Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  d.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  d.connectionState.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        d.connectionState ==
                                            DeviceConnectionState.online
                                        ? Colors.green
                                        : d.connectionState ==
                                              DeviceConnectionState.stale
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Last reading: ${_ago(d.lastSeen)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                _MiniStat(
                                  label: 'Moisture',
                                  value: d.latestReading?.soilMoisture == null
                                      ? '—'
                                      : '${d.latestReading!.soilMoisture!.toStringAsFixed(0)}%',
                                ),
                                _MiniStat(
                                  label: 'Temp',
                                  value: d.latestReading?.temperature == null
                                      ? '—'
                                      : '${d.latestReading!.temperature!.toStringAsFixed(0)}°C',
                                ),
                                _MiniStat(
                                  label: 'Humidity',
                                  value: d.latestReading?.humidity == null
                                      ? '—'
                                      : '${d.latestReading!.humidity!.toStringAsFixed(0)}%',
                                ),
                                _MiniStat(
                                  label: 'Rain',
                                  value: d.latestReading?.rainfall == null
                                      ? '—'
                                      : '${d.latestReading!.rainfall!.toStringAsFixed(0)}mm',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  _Agg _aggregate(List<DeviceModel> farmDevices) {
    final readings = farmDevices
        .map((d) => d.latestReading)
        .whereType<SensorReading>()
        .toList();
    if (readings.isEmpty) return const _Agg();
    double? avg(double? Function(SensorReading) f) {
      final vs = readings.map(f).whereType<double>().toList();
      if (vs.isEmpty) return null;
      return vs.reduce((a, b) => a + b) / vs.length;
    }

    return _Agg(
      moisture: avg((r) => r.soilMoisture),
      temp: avg((r) => r.temperature),
      humidity: avg((r) => r.humidity),
      rain: avg((r) => r.rainfall),
    );
  }

  _MetricStatus _soilStatus(double? v) {
    if (v == null) return _MetricStatus.neutral;
    if (v < 15) return _MetricStatus.critical;
    if (v < 25 || v > 90) return _MetricStatus.warning;
    return _MetricStatus.good;
  }

  _MetricStatus _tempStatus(double? v) {
    if (v == null) return _MetricStatus.neutral;
    if (v > 42) return _MetricStatus.warning;
    if (v < 5) return _MetricStatus.warning;
    return _MetricStatus.good;
  }

  _MetricStatus _humidityStatus(double? v) {
    if (v == null) return _MetricStatus.neutral;
    if (v > 94) return _MetricStatus.warning;
    return _MetricStatus.good;
  }

  _MetricStatus _rainStatus(double? v) {
    if (v == null) return _MetricStatus.neutral;
    if (v > 150) return _MetricStatus.warning;
    return _MetricStatus.good;
  }
}

class _Agg {
  final double? moisture;
  final double? temp;
  final double? humidity;
  final double? rain;
  const _Agg({this.moisture, this.temp, this.humidity, this.rain});
}

enum _MetricStatus { good, warning, critical, neutral }

enum _AlertLevel { critical, warning, info }

extension on _AlertLevel {
  Color get color {
    switch (this) {
      case _AlertLevel.critical:
        return Colors.red;
      case _AlertLevel.warning:
        return Colors.orange;
      case _AlertLevel.info:
        return Colors.blue;
    }
  }

  Color get bg {
    switch (this) {
      case _AlertLevel.critical:
        return Colors.red.withOpacity(0.08);
      case _AlertLevel.warning:
        return Colors.orange.withOpacity(0.08);
      case _AlertLevel.info:
        return Colors.blue.withOpacity(0.08);
    }
  }

  IconData get icon {
    switch (this) {
      case _AlertLevel.critical:
        return Icons.error;
      case _AlertLevel.warning:
        return Icons.warning_amber_rounded;
      case _AlertLevel.info:
        return Icons.info_outline;
    }
  }
}

class _LiveAlert {
  final _AlertLevel severity;
  final String title;
  final String message;
  const _LiveAlert({
    required this.severity,
    required this.title,
    required this.message,
  });
}

class _StatusPill extends StatelessWidget {
  final List<DeviceModel> devices;
  const _StatusPill({required this.devices});

  @override
  Widget build(BuildContext context) {
    final online = devices
        .where((d) => d.connectionState == DeviceConnectionState.online)
        .length;
    final total = devices.length;
    Color color;
    String text;
    if (total == 0) {
      color = Colors.grey;
      text = 'Live: —';
    } else if (online == total) {
      color = Colors.green;
      text = 'LIVE';
    } else if (online > 0) {
      color = Colors.orange;
      text = 'Partial';
    } else {
      color = Colors.red;
      text = 'Offline';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LiveMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final _MetricStatus status;
  const _LiveMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final (color, dot) = switch (status) {
      _MetricStatus.good => (Colors.green, Colors.green),
      _MetricStatus.warning => (Colors.orange, Colors.orange),
      _MetricStatus.critical => (Colors.red, Colors.red),
      _MetricStatus.neutral => (Colors.grey, Colors.grey),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700, color: color),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color
                  ?.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
