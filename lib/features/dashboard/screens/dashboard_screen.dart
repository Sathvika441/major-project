import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device/device_model.dart';
import '../../../models/farm/farm_model.dart';
import '../../../repositories/device/device_repository.dart';
import '../../../repositories/farm/farm_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../devices/screens/device_management_screen.dart';
import '../../farm/screens/farm_management_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ArecaSmart'),
        actions: [
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
                return FutureBuilder<List<PlotModel>>(
                  future: ref.read(farmRepositoryProvider).getPlots(farm.id),
                  builder: (context, plotsSnapshot) {
                    if (plotsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (plotsSnapshot.hasError) {
                      return _empty(
                        context,
                        'Could not load plots',
                        'Please try again.',
                      );
                    }

                    final plots = plotsSnapshot.data ?? [];
                    final plot = plots.isEmpty ? null : plots.first;

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
                        final device =
                            plot == null ? null : _deviceFor(plot, devices);
                        final reading = device?.latestReading;

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
                              Text(
                                '${farm.name} • ${plot?.name ?? 'No plot selected'}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 16),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Crop status',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        plot == null
                                            ? 'Add a plot to track crop age.'
                                            : '${plot.crop} • ${plot.cropAgeDays} days old',
                                      ),
                                      if (plot != null)
                                        Text(
                                          'Growth stage: ${plot.growthStage}',
                                        ),
                                      const SizedBox(height: 8),
                                      Text(
                                        device == null
                                            ? 'Device: not assigned'
                                            : 'Device: ${device.connectionState.name}',
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
                                    value: reading?.soilMoisture == null
                                        ? '—'
                                        : '${reading!.soilMoisture!.toStringAsFixed(1)} %',
                                  ),
                                  _MetricCard(
                                    icon: Icons.thermostat,
                                    label: 'Temperature',
                                    value: reading?.temperature == null
                                        ? '—'
                                        : '${reading!.temperature!.toStringAsFixed(1)} °C',
                                  ),
                                  _MetricCard(
                                    icon: Icons.cloud,
                                    label: 'Humidity',
                                    value: reading?.humidity == null
                                        ? '—'
                                        : '${reading!.humidity!.toStringAsFixed(1)} %',
                                  ),
                                  _MetricCard(
                                    icon: Icons.water,
                                    label: 'Rainfall',
                                    value: reading?.rainfall == null
                                        ? '—'
                                        : '${reading!.rainfall!.toStringAsFixed(1)} mm',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: ListTile(
                                  leading: Icon(
                                    device?.connectionState ==
                                            DeviceConnectionState.online
                                        ? Icons.check_circle
                                        : Icons.warning_amber_rounded,
                                  ),
                                  title: const Text('Irrigation summary'),
                                  subtitle: Text(
                                    device == null
                                        ? 'Connect a sensor to evaluate irrigation conditions.'
                                        : 'Decision engine input is ready: sensor + crop age + growth stage + environment.',
                                  ),
                                  trailing:
                                      const Icon(Icons.chevron_right),
                                ),
                              ),
                              const Card(
                                child: ListTile(
                                  leading: Icon(Icons.notifications_none),
                                  title: Text('Active alerts'),
                                  subtitle: Text(
                                    'Alerts will appear here as events are integrated.',
                                  ),
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
                );
              },
            ),
    );
  }

  DeviceModel? _deviceFor(PlotModel plot, List<DeviceModel> devices) {
    for (final device in devices) {
      if (device.plotId == plot.id) return device;
    }
    return null;
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
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
