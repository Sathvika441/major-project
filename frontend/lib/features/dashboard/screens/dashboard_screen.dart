import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/device/device_model.dart';
import '../../../models/farm/farm_model.dart';
import '../../../repositories/device/device_repository.dart';
import '../../../repositories/farm/farm_repository.dart';
import '../../../services/backend/backend_api.dart';
import '../../../services/sensors/simulated_sensor_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../devices/screens/device_management_screen.dart';
import '../../farm/screens/farm_management_screen.dart';
import '../../profile/screens/profile_edit_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _testDemoBackend(BuildContext context, WidgetRef ref) async {
    final reading = ref.read(simulatedSensorProvider).generateReading();
    try {
      final result = await ref.read(backendApiProvider).predict({
        'soil_moisture': reading.soilMoisture,
        'temperature': reading.temperature,
        'humidity': reading.humidity,
        'rainfall': reading.rainfall,
        'source': 'simulated',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['detail']?.toString() ?? 'Backend response received.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Demo backend call: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

                final farm = farms.first;
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
                    final alerts = _generateAlerts(farmDevices);
                    final agg = _aggregate(farmDevices);

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(farmsProvider);
                        ref.invalidate(devicesProvider);
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'Good day, ${user?.name ?? 'Farmer'}',
                            style:
                                Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${farm.name} â€¢ ${farm.location}',
                                  style:
                                      Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const FarmManagementScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Manage'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.science_outlined),
                              title: const Text('Simulated sensor data'),
                              subtitle: const Text('Development-only readings until real sensors are available.'),
                              trailing: FilledButton(
                                onPressed: () => _testDemoBackend(context, ref),
                                child: const Text('Test backend'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Farm Overview',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${farm.sizeAcres} acres â€¢ ${farm.irrigationMethod} irrigation',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Water source: ${farm.waterSource}',
                                  ),
                                  const SizedBox(height: 10),
                                  Divider(
                                      color: Theme.of(context)
                                          .dividerColor),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        farmDevices.isEmpty
                                            ? Icons.sensors_off
                                            : farmDevices.any((d) =>
                                                    d.connectionState ==
                                                    DeviceConnectionState
                                                        .online)
                                                ? Icons.check_circle
                                                : Icons
                                                    .warning_amber_rounded,
                                        color: farmDevices.isEmpty
                                            ? Colors.grey
                                            : farmDevices.any((d) =>
                                                    d.connectionState ==
                                                    DeviceConnectionState
                                                        .online)
                                                ? Colors.green
                                                : Colors.orange,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${farmDevices.length} device(s) assigned',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      const Spacer(),
                                      _statusChip(context, farmDevices),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            children: [
                              _MetricCard(
                                icon: Icons.water_drop,
                                label: 'Soil moisture',
                                value: agg.soilMoisture == null
                                    ? 'â€”'
                                    : '${agg.soilMoisture!.toStringAsFixed(1)} %',
                                warn: agg.soilMoisture != null &&
                                    (agg.soilMoisture! < 20 ||
                                        agg.soilMoisture! > 85),
                              ),
                              _MetricCard(
                                icon: Icons.thermostat,
                                label: 'Temperature',
                                value: agg.temperature == null
                                    ? 'â€”'
                                    : '${agg.temperature!.toStringAsFixed(1)} Â°C',
                                warn: agg.temperature != null &&
                                    (agg.temperature! < 10 ||
                                        agg.temperature! > 42),
                              ),
                              _MetricCard(
                                icon: Icons.cloud,
                                label: 'Humidity',
                                value: agg.humidity == null
                                    ? 'â€”'
                                    : '${agg.humidity!.toStringAsFixed(1)} %',
                              ),
                              _MetricCard(
                                icon: Icons.water,
                                label: 'Rainfall',
                                value: agg.rainfall == null
                                    ? 'â€”'
                                    : '${agg.rainfall!.toStringAsFixed(1)} mm',
                                warn: agg.rainfall != null &&
                                    agg.rainfall! > 150,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: ListTile(
                              leading: Icon(
                                farmDevices.isEmpty
                                    ? Icons.info_outline
                                    : farmDevices.any((d) =>
                                            d.connectionState ==
                                            DeviceConnectionState.online)
                                        ? Icons.check_circle
                                        : Icons.warning_amber_rounded,
                                color: farmDevices.isEmpty
                                    ? Colors.grey
                                    : farmDevices.any((d) =>
                                            d.connectionState ==
                                            DeviceConnectionState.online)
                                        ? Colors.green
                                        : Colors.orange,
                              ),
                              title: const Text('Irrigation status'),
                              subtitle: Text(
                                farmDevices.isEmpty
                                    ? 'No sensors assigned to this farm yet.'
                                    : agg.hasReading
                                        ? 'Decision engine ready â€” sensor data available.'
                                        : 'Sensors online, awaiting first reading.',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          ),
                          Card(
                            child: ExpansionTile(
                              leading: Icon(
                                alerts.isEmpty
                                    ? Icons.notifications_none
                                    : Icons.notification_important,
                                color: alerts.isEmpty
                                    ? Colors.grey
                                    : (alerts.any((a) => a.severity ==
                                            _AlertSeverity.critical)
                                        ? Colors.red
                                        : Colors.orange),
                              ),
                              title: Text(
                                alerts.isEmpty
                                    ? 'No active alerts'
                                    : '${alerts.length} active alert(s)',
                              ),
                              subtitle: Text(alerts.isEmpty
                                  ? 'Farm conditions are within normal ranges.'
                                  : 'Tap to view details'),
                              children: alerts.isEmpty
                                  ? [
                                      const Padding(
                                        padding: EdgeInsets.fromLTRB(
                                            16, 0, 16, 16),
                                        child: Text(
                                          'Alerts will appear here as sensor events or irrigation conditions are detected.',
                                        ),
                                      )
                                    ]
                                  : [
                                      ...alerts.map((a) => ListTile(
                                            leading: Icon(
                                              a.severity.icon,
                                              color: a.severity.color,
                                            ),
                                            title: Text(a.title),
                                            subtitle: Text(a.message),
                                            dense: true,
                                          )),
                                    ],
                            ),
                          ),
                          const Card(
                            child: ListTile(
                              leading: Icon(Icons.history),
                              title: Text('Recent activity'),
                              subtitle: Text(
                                'Sensor and irrigation history will be shown here.',
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
                '${r.soilMoisture!.toStringAsFixed(1)}% â€” irrigation recommended.',
          ));
        }
        if (r.soilMoisture != null && r.soilMoisture! > 90) {
          alerts.add(_FarmAlert(
            severity: _AlertSeverity.warning,
            title: 'High soil moisture on ${d.name}',
            message:
                '${r.soilMoisture!.toStringAsFixed(1)}% â€” risk of waterlogging.',
          ));
        }
        if (r.temperature != null && r.temperature! > 40) {
          alerts.add(_FarmAlert(
            severity: _AlertSeverity.warning,
            title: 'High temperature (${r.temperature!.toStringAsFixed(1)}Â°C)',
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
              onPressed: () => context.go('/onboarding'),
              icon: const Icon(Icons.add_business),
              label: const Text('Set up farm'),
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

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool warn;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warn ? Colors.orange : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

