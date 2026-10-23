import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/backend/backend_api.dart';

class IoTDeviceControls extends ConsumerStatefulWidget {
  final String deviceId;
  const IoTDeviceControls({super.key, required this.deviceId});

  @override
  ConsumerState<IoTDeviceControls> createState() => _IoTDeviceControlsState();
}

class _IoTDeviceControlsState extends ConsumerState<IoTDeviceControls> {
  Map<String, dynamic>? _status;
  bool _loading = false;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(backendApiProvider).getIoTStatus(widget.deviceId);
      if (!mounted) return;
      setState(() { _status = result; _loading = false; });
    } on BackendApiException catch (error) {
      if (!mounted) return;
      setState(() { _error = error.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not contact the IoT API. Check backend and Firebase Admin configuration.';
        _loading = false;
      });
    }
  }

  Future<void> _control({String? mode, bool? pumpOn, bool? emergencyStop}) async {
    if (_acting) return;
    setState(() { _acting = true; _error = null; });
    try {
      final api = ref.read(backendApiProvider);
      if (emergencyStop != null) {
        await api.setIoTEmergencyStop(widget.deviceId, active: emergencyStop);
      } else {
        await api.setIoTControl(widget.deviceId, mode: mode, pumpOn: pumpOn);
      }
      await _refresh();
    } on BackendApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'The control request failed. Verify backend connectivity.');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _showHistory() async {
    setState(() => _acting = true);
    try {
      final result = await ref.read(backendApiProvider).getIoTReadings(widget.deviceId, limit: 50);
      if (!mounted) return;
      final readings = (result['readings'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
          .reversed
          .toList();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sensor history', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text('Latest ${readings.length} persisted readings'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: readings.isEmpty
                        ? const Center(child: Text('No persisted readings yet.'))
                        : ListView.separated(
                            itemCount: readings.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final reading = readings[index];
                              final moisture = reading['soil_moisture_percent'];
                              final time = reading['observed_at'] ?? reading['received_at'];
                              final value = moisture is num ? moisture.toStringAsFixed(1) : '—';
                              return ListTile(
                                leading: const Icon(Icons.water_drop_outlined),
                                title: Text('Soil moisture: $value%'),
                                subtitle: Text(time?.toString() ?? 'Time unavailable'),
                                trailing: reading['sensor_valid'] == false
                                    ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } on BackendApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Sensor history is unavailable. Check Firestore configuration.');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final command = Map<String, dynamic>.from((_status?['command'] as Map?) ?? const {});
    final reading = Map<String, dynamic>.from((_status?['latest_reading'] as Map?) ?? const {});
    final mode = command['mode']?.toString() ?? 'unknown';
    final pumpOn = command['pump_on'] == true;
    final stopActive = command['emergency_stop'] == true;
    final moisture = reading['soil_moisture_percent'];
    final moistureText = moisture is num ? '${moisture.toStringAsFixed(1)}%' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        Row(
          children: [
            const Icon(Icons.water_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text('IoT irrigation', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: 'Refresh IoT status',
              onPressed: _loading || _acting ? null : _refresh,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(label: 'Mode: ${mode.toUpperCase()}', icon: Icons.tune),
            _StatusChip(label: pumpOn ? 'Pump ON' : 'Pump OFF', icon: pumpOn ? Icons.water : Icons.water_drop_outlined, warning: pumpOn),
            _StatusChip(label: stopActive ? 'Emergency stop ACTIVE' : 'Emergency stop clear', icon: Icons.emergency, warning: stopActive),
            _StatusChip(label: 'Moisture: $moistureText', icon: Icons.grass_outlined),
          ],
        ),
        if (command['reason'] != null) ...[
          const SizedBox(height: 8),
          Text(command['reason'].toString(), style: theme.textTheme.bodySmall),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: _acting ? null : () => _control(mode: 'auto'), child: const Text('Automatic mode')),
            OutlinedButton(onPressed: _acting ? null : () => _control(mode: 'manual', pumpOn: false), child: const Text('Manual mode / OFF')),
            FilledButton.tonal(onPressed: _acting || stopActive ? null : () => _control(mode: 'manual', pumpOn: true), child: const Text('Request pump ON')),
            OutlinedButton(onPressed: _acting ? null : () => _control(mode: 'manual', pumpOn: false), child: const Text('Pump OFF')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError),
              onPressed: _acting || stopActive ? null : () => _control(emergencyStop: true),
              child: const Text('Emergency stop'),
            ),
            if (stopActive)
              OutlinedButton(onPressed: _acting ? null : () => _control(emergencyStop: false), child: const Text('Clear stop')),
            TextButton.icon(onPressed: _acting ? null : _showHistory, icon: const Icon(Icons.history), label: const Text('History')),
          ],
        ),
        if (_acting) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        const SizedBox(height: 4),
        Text(
          'Control requests are safety-gated by the backend. A pump ON request may be blocked by active safety rules.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool warning;
  const _StatusChip({required this.label, required this.icon, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? scheme.error : scheme.primary;
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
