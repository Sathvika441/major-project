import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/device/device_model.dart';
import '../../../repositories/device/device_repository.dart';
import '../widgets/iot_device_controls.dart';
import '../../../widgets/app_navigation_scaffold.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../farm/screens/farm_management_screen.dart';

final devicesProvider = FutureProvider.autoDispose<List<DeviceModel>>((
  ref,
) async {
  final uid = ref.watch(authControllerProvider).user?.uid;
  if (uid == null) return [];
  return ref.watch(deviceRepositoryProvider).getDevices(uid);
});

class DeviceManagementScreen extends ConsumerWidget {
  const DeviceManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);

    return AppNavigationScaffold(
      title: 'Devices & sensors',
      subtitle: 'Monitor connectivity and available field readings',
      selectedIndex: 3,
      actions: [
        IconButton(
          tooltip: 'Refresh devices',
          onPressed: () => ref.invalidate(devicesProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _register(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Register device'),
      ),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Unable to load devices.\n$error',
          onRetry: () => ref.invalidate(devicesProvider),
        ),
        data: (items) {
          final online = items
              .where(
                (device) =>
                    device.connectionState == DeviceConnectionState.online,
              )
              .length;
          final offline = items.length - online;

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1200
                  ? 3
                  : constraints.maxWidth >= 720
                  ? 2
                  : 1;
              const gap = 18.0;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - gap * (columns - 1)) / columns;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
                children: [
                  _DeviceSummary(
                    total: items.length,
                    online: online,
                    offline: offline,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Hardware-ready setup: register the sensor ID and assign it to a farm now. A registered device stays “Not connected” until valid telemetry arrives. No live readings are fabricated and this page will not operate a pump without a compatible controller integration.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (items.isEmpty)
                    const _EmptyDeviceState()
                  else
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: items
                          .map(
                            (device) => SizedBox(
                              width: width,
                              child: _DeviceCard(device: device),
                            ),
                          )
                          .toList(),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final id = TextEditingController();
    final name = TextEditingController();
    final key = GlobalKey<FormState>();
    final farms = await ref.read(farmsProvider.future);
    final existingDevices = await ref.read(devicesProvider.future);
    if (!context.mounted) return;

    String? selectedFarmId = farms.isNotEmpty ? farms.first.id : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Register device'),
          content: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: id,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      hintText: 'Example: SENSOR-001',
                    ),
                    maxLength: 50,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9_-]'),
                      ),
                    ],
                    validator: (value) {
                      final candidate = value?.trim() ?? '';
                      if (candidate.isEmpty) return 'Enter the device ID';
                      if (candidate.length < 3 || candidate.length > 50)
                        return 'Use 3–50 characters';
                      if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(candidate)) {
                        return 'Use letters, numbers, hyphens or underscores only';
                      }
                      if (existingDevices.any(
                        (device) =>
                            device.deviceId.trim().toLowerCase() ==
                            candidate.toLowerCase(),
                      )) {
                        return 'This device ID is already registered';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Device name',
                      hintText: 'Example: Soil Sensor 1',
                    ),
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[<>]')),
                    ],
                    validator: (value) {
                      final candidate = value?.trim() ?? '';
                      if (candidate.isEmpty) return 'Enter a device name';
                      if (candidate.length < 2 || candidate.length > 60)
                        return 'Use 2–60 characters';
                      if (candidate.contains(RegExp(r'[<>]')))
                        return 'Remove unsupported characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (farms.isEmpty)
                    const Text('Add a farm before registering a device.')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedFarmId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assign to farm',
                      ),
                      items: farms
                          .map(
                            (farm) => DropdownMenuItem(
                              value: farm.id,
                              child: Text(
                                farm.name.isEmpty ? 'Unnamed farm' : farm.name,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedFarmId = value),
                      validator: (value) =>
                          value == null ? 'Select a farm' : null,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: farms.isEmpty
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) return;
                      final uid = ref.read(authControllerProvider).user!.uid;
                      try {
                        await ref
                            .read(deviceRepositoryProvider)
                            .register(
                              DeviceModel(
                                id:
                                    'device_' +
                                    DateTime.now().microsecondsSinceEpoch
                                        .toString(),
                                userId: uid,
                                farmId: selectedFarmId!,
                                plotId: '',
                                deviceId: id.text.trim(),
                                name: name.text.trim(),
                                lastSeen: DateTime.now(),
                              ),
                            );
                        ref.invalidate(devicesProvider);
                        ref.invalidate(farmsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (error) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );

    id.dispose();
    name.dispose();
  }
}

class _DeviceSummary extends StatelessWidget {
  final int total;
  final int online;
  final int offline;

  const _DeviceSummary({
    required this.total,
    required this.online,
    required this.offline,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _SummaryMetric(
                icon: Icons.sensors_rounded,
                value: total.toString(),
                label: 'Total devices',
                color: scheme.primary,
              ),
            ),
            Container(width: 1, height: 44, color: scheme.outlineVariant),
            Expanded(
              child: _SummaryMetric(
                icon: Icons.check_circle_outline_rounded,
                value: online.toString(),
                label: 'Online',
                color: scheme.primary,
              ),
            ),
            Container(width: 1, height: 44, color: scheme.outlineVariant),
            Expanded(
              child: _SummaryMetric(
                icon: Icons.sync_problem_outlined,
                value: offline.toString(),
                label: 'Not connected',
                color: offline == 0 ? scheme.primary : scheme.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;

  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final reading = device.latestReading;
    final connection = device.connectionState;
    final online = connection == DeviceConnectionState.online;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: online
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    online ? Icons.sensors_rounded : Icons.sensors_off_outlined,
                    color: online ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    device.name.isEmpty ? 'Unnamed device' : device.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusPill(state: connection),
              ],
            ),
            const SizedBox(height: 16),
            Text(device.deviceId, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              reading == null
                  ? 'Waiting for first telemetry packet'
                  : 'Last seen ' + _ago(device.lastSeen),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            if (reading == null)
              _NoReading()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ReadingPill(
                    icon: Icons.water_drop_outlined,
                    label: 'Soil',
                    value: reading.soilMoisture,
                    unit: '%',
                  ),
                  _ReadingPill(
                    icon: Icons.thermostat_outlined,
                    label: 'Temp',
                    value: reading.temperature,
                    unit: '°C',
                  ),
                  _ReadingPill(
                    icon: Icons.opacity_outlined,
                    label: 'Humidity',
                    value: reading.humidity,
                    unit: '%',
                  ),
                  _ReadingPill(
                    icon: Icons.waterfall_chart_outlined,
                    label: 'Rain',
                    value: reading.rainfall,
                    unit: 'mm',
                  ),
                ],
              ),
            const SizedBox(height: 8),
            IoTDeviceControls(deviceId: device.deviceId),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1)
      return difference.inMinutes.toString() + ' min ago';
    if (difference.inDays < 1) return difference.inHours.toString() + ' hr ago';
    return difference.inDays.toString() + ' d ago';
  }
}

class _StatusPill extends StatelessWidget {
  final DeviceConnectionState state;

  const _StatusPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (state) {
      DeviceConnectionState.online => scheme.primary,
      DeviceConnectionState.stale => scheme.onTertiaryContainer,
      DeviceConnectionState.offline => scheme.error,
      DeviceConnectionState.unknown => scheme.onTertiaryContainer,
    };
    final label = switch (state) {
      DeviceConnectionState.online => 'ONLINE',
      DeviceConnectionState.stale => 'STALE',
      DeviceConnectionState.offline => 'OFFLINE',
      DeviceConnectionState.unknown => 'NOT CONNECTED',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ReadingPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? value;
  final String unit;

  const _ReadingPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label + ' '),
          Text(
            value == null ? '—' : value!.toStringAsFixed(1) + unit,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _NoReading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.sensors_off_outlined, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('No sensor reading available yet.')),
        ],
      ),
    );
  }
}

class _EmptyDeviceState extends StatelessWidget {
  const _EmptyDeviceState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sensors_off_rounded,
                size: 36,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No devices registered',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Register an IoT sensor and assign it to a farm to start receiving field readings.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'No sensor values are generated yet. Real readings will appear after a compatible device sends telemetry.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
