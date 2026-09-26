import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/device/device_model.dart';
import '../../../repositories/device/device_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../farm/screens/farm_management_screen.dart';

final devicesProvider = FutureProvider.autoDispose<List<DeviceModel>>((ref) async {
  final uid = ref.watch(authControllerProvider).user?.uid;
  if (uid == null) return [];
  return ref.watch(deviceRepositoryProvider).getDevices(uid);
});

class DeviceManagementScreen extends ConsumerWidget {
  const DeviceManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      drawer: _buildNavigationDrawer(context, ref, user?.name ?? 'Farmer'),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Open navigation',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Devices & sensors'),
        actions: [
          IconButton(
            tooltip: 'Refresh devices',
            onPressed: () => ref.invalidate(devicesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _register(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Register device'),
      ),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: 'Unable to load devices.\n$e',
          onRetry: () => ref.invalidate(devicesProvider),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyDeviceState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: items.length,
                itemBuilder: (_, i) => _DeviceTile(device: items[i]),
              ),
      ),
    );
  }

  Widget _buildNavigationDrawer(
    BuildContext context,
    WidgetRef ref,
    String farmerName,
  ) {
    final scheme = Theme.of(context).colorScheme;
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
                  ),
                  _drawerItem(
                    context,
                    Icons.sensors_outlined,
                    'Devices',
                    () => context.go('/devices'),
                    selected: true,
                  ),
                  _drawerItem(
                    context,
                    Icons.notifications_none_rounded,
                    'Alerts',
                    () => context.go('/dashboard'),
                  ),
                  _drawerItem(
                    context,
                    Icons.person_outline_rounded,
                    'Profile',
                    () => context.go('/profile'),
                  ),
                  _drawerItem(
                    context,
                    Icons.settings_outlined,
                    'Farm management',
                    () => context.go('/farms'),
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

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool selected = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final id = TextEditingController();
    final name = TextEditingController();
    final key = GlobalKey<FormState>();
    final farms = await ref.read(farmsProvider.future);
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
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Device name',
                      hintText: 'Example: Soil Sensor 1',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  if (farms.isEmpty)
                    const Text('Add a farm before registering a device.')
                  else
                    DropdownButtonFormField<String>(
                      value: selectedFarmId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assign to farm',
                      ),
                      items: farms
                          .map(
                            (farm) => DropdownMenuItem(
                              value: farm.id,
                              child: Text(
                                farm.name.isEmpty
                                    ? 'Unnamed farm'
                                    : farm.name,
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
                      await ref.read(deviceRepositoryProvider).register(
                        DeviceModel(
                          id: 'device_${DateTime.now().microsecondsSinceEpoch}',
                          userId: uid,
                          farmId: selectedFarmId!,
                          plotId: '',
                          deviceId: id.text.trim(),
                          name: name.text.trim(),
                          lastSeen: DateTime.now(),
                        ),
                      );
                      ref.invalidate(devicesProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
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

class _EmptyDeviceState extends StatelessWidget {
  const _EmptyDeviceState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.sensors_off_rounded,
                      size: 34,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No devices registered',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Register an IoT sensor and assign it to a farm to start receiving live readings.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Soil moisture is simulated for now'),
                  ),
                ],
              ),
            ),
          ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final DeviceModel device;

  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    final reading = device.latestReading;
    final state = device.connectionState;
    final status = state.name.toUpperCase();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        leading: CircleAvatar(
          backgroundColor: state == DeviceConnectionState.online
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          child: Icon(
            state == DeviceConnectionState.online
                ? Icons.sensors_rounded
                : Icons.sensors_off_outlined,
            color: state == DeviceConnectionState.online
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          device.name.isEmpty ? 'Unnamed device' : device.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${device.deviceId}\n$status • Last seen ${_ago(device.lastSeen)}',
        ),
        children: [
          if (reading == null)
            const ListTile(
              leading: Icon(Icons.sensors_off),
              title: Text('No sensor reading available'),
            )
          else ...[
            _metric(
              'Soil moisture',
              reading.soilMoisture,
              '%',
              Icons.water_drop_outlined,
            ),
            _metric(
              'Temperature',
              reading.temperature,
              '°C',
              Icons.thermostat_outlined,
            ),
            _metric(
              'Humidity',
              reading.humidity,
              '%',
              Icons.opacity_outlined,
            ),
            _metric(
              'Rainfall',
              reading.rainfall,
              'mm',
              Icons.waterfall_chart_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(
    String label,
    double? value,
    String unit,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value == null ? '—' : '${value.toStringAsFixed(1)} $unit',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  String _ago(DateTime value) {
    final d = DateTime.now().difference(value);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} hr ago';
    return '${d.inDays} d ago';
  }
}
