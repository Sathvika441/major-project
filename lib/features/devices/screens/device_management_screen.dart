import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device/device_model.dart';
import '../../../repositories/device/device_repository.dart';
// import '../../../repositories/farm/farm_repository.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Devices & sensors')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _register(context, ref), icon: const Icon(Icons.add), label: const Text('Register device')),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load devices.\n$e')),
        data: (items) => items.isEmpty ? const Center(child: Text('No devices registered.')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: items.length, itemBuilder: (_, i) => _DeviceTile(device: items[i])),
      ),
    );
  }

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final id = TextEditingController(); final name = TextEditingController(); final plot = TextEditingController();
    final key = GlobalKey<FormState>();
    final farms = await ref.read(farmsProvider.future);
    if (!context.mounted) return;
    await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Register device'), content: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: id, decoration: const InputDecoration(labelText: 'Device ID'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
      TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Device name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
      TextFormField(controller: plot, decoration: const InputDecoration(labelText: 'Plot ID'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
      const SizedBox(height: 8), Text('Available farms: ${farms.length}'),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () async { if (!key.currentState!.validate()) return; final uid = ref.read(authControllerProvider).user!.uid; final farmId = farms.isEmpty ? 'unassigned' : farms.first.id; await ref.read(deviceRepositoryProvider).register(DeviceModel(id: 'device_${DateTime.now().microsecondsSinceEpoch}', userId: uid, farmId: farmId, plotId: plot.text.trim(), deviceId: id.text.trim(), name: name.text.trim(), lastSeen: DateTime.now())); ref.invalidate(devicesProvider); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('Register'))]));
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
    return Card(child: ExpansionTile(title: Text(device.name), subtitle: Text('${device.deviceId} • Plot ${device.plotId}\n$status • Last seen ${_ago(device.lastSeen)}'), children: [
      if (reading == null) const ListTile(leading: Icon(Icons.sensors_off), title: Text('No sensor reading available'))
      else ...[
        _metric('Soil moisture', reading.soilMoisture, '%'), _metric('Temperature', reading.temperature, '°C'), _metric('Humidity', reading.humidity, '%'), _metric('Rainfall', reading.rainfall, 'mm'),
      ],
    ]));
  }

  Widget _metric(String label, double? value, String unit) => ListTile(title: Text(label), trailing: Text(value == null ? '—' : '${value.toStringAsFixed(1)} $unit', style: const TextStyle(fontWeight: FontWeight.bold)));
  String _ago(DateTime value) { final d = DateTime.now().difference(value); if (d.inMinutes < 1) return 'just now'; if (d.inHours < 1) return '${d.inMinutes} min ago'; if (d.inDays < 1) return '${d.inHours} hr ago'; return '${d.inDays} d ago'; }
}
