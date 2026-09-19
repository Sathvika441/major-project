import 'dart:async';

import 'irrigation_audit.dart';
import 'irrigation_models.dart';

abstract class PumpDriver {
  Future<void> start(Duration duration);
  Future<void> stop();
  Future<void> emergencyStop();
}

class SimulatedPumpDriver implements PumpDriver {
  bool running = false;
  @override Future<void> start(Duration duration) async => running = true;
  @override Future<void> stop() async => running = false;
  @override Future<void> emergencyStop() async => running = false;
}

class PumpCommandResult {
  final bool accepted;
  final String commandId;
  final String message;
  const PumpCommandResult({required this.accepted, required this.commandId, required this.message});
}

class SafePumpController {
  final PumpDriver driver;
  final IrrigationAuditLog audit;
  final Duration maxRuntime;
  final Duration duplicateWindow;
  Timer? _timeout;
  String? _activeCommandId;
  DateTime? _lastCommandAt;
  bool _emergencyStopped = false;

  SafePumpController({
    required this.driver,
    required this.audit,
    this.maxRuntime = const Duration(minutes: 30),
    this.duplicateWindow = const Duration(minutes: 2),
  });

  bool get isRunning => _activeCommandId != null;
  bool get isEmergencyStopped => _emergencyStopped;

  Future<PumpCommandResult> start({
    required String commandId,
    required Duration duration,
    required IrrigationMode mode,
    required bool confirmed,
    String? decisionId,
    String reason = 'Pump start command',
  }) async {
    if (duration <= Duration.zero || duration > maxRuntime) {
      return _reject(commandId, decisionId, 'Pump runtime exceeds the safety limit of ' + maxRuntime.inMinutes.toString() + ' minutes.');
    }
    if (mode == IrrigationMode.recommendationOnly) {
      return _reject(commandId, decisionId, 'Recommendation-only mode cannot start the pump.');
    }
    if (mode == IrrigationMode.manual && !confirmed) {
      return _reject(commandId, decisionId, 'Manual pump start requires explicit confirmation.');
    }
    if (_emergencyStopped) {
      return _reject(commandId, decisionId, 'Pump is emergency-stopped and must be reset before starting.');
    }
    if (_activeCommandId != null) {
      return _reject(commandId, decisionId, 'A pump command is already running.');
    }
    if (_lastCommandAt != null && DateTime.now().difference(_lastCommandAt!) < duplicateWindow) {
      return _reject(commandId, decisionId, 'Duplicate pump command blocked by safety cooldown.');
    }

    _activeCommandId = commandId;
    _lastCommandAt = DateTime.now();
    try {
      await driver.start(duration);
      await _recordPump(commandId, decisionId, 'start', 'accepted', reason, {'mode': mode.name, 'durationSeconds': duration.inSeconds});
      _timeout?.cancel();
      _timeout = Timer(duration, () async {
        await stop(commandId: commandId, decisionId: decisionId, reason: 'Safety timeout reached');
      });
      return PumpCommandResult(accepted: true, commandId: commandId, message: 'Pump started for ' + duration.inMinutes.toString() + ' minute(s).');
    } catch (e) {
      _activeCommandId = null;
      await _recordPump(commandId, decisionId, 'start', 'failed', 'Pump driver failed: ' + e.toString(), {});
      return PumpCommandResult(accepted: false, commandId: commandId, message: 'Pump start failed: ' + e.toString());
    }
  }

  Future<PumpCommandResult> stop({required String commandId, String? decisionId, String reason = 'Pump stopped'}) async {
    if (_activeCommandId != commandId) return _reject(commandId, decisionId, 'No matching active pump command.');
    _timeout?.cancel();
    try {
      await driver.stop();
      _activeCommandId = null;
      await _recordPump(commandId, decisionId, 'stop', 'accepted', reason, {});
      return PumpCommandResult(accepted: true, commandId: commandId, message: 'Pump stopped.');
    } catch (e) {
      await _recordPump(commandId, decisionId, 'stop', 'failed', 'Pump stop failed: ' + e.toString(), {});
      return PumpCommandResult(accepted: false, commandId: commandId, message: 'Pump stop failed: ' + e.toString());
    }
  }

  Future<PumpCommandResult> emergencyStop({String? decisionId, String reason = 'Emergency stop'}) async {
    _timeout?.cancel();
    final commandId = _activeCommandId ?? 'emergency_' + DateTime.now().microsecondsSinceEpoch.toString();
    try {
      await driver.emergencyStop();
      _activeCommandId = null;
      _emergencyStopped = true;
      await _recordPump(commandId, decisionId, 'emergency_stop', 'accepted', reason, {});
      return PumpCommandResult(accepted: true, commandId: commandId, message: 'Emergency stop activated.');
    } catch (e) {
      await _recordPump(commandId, decisionId, 'emergency_stop', 'failed', 'Emergency stop failed: ' + e.toString(), {});
      return PumpCommandResult(accepted: false, commandId: commandId, message: 'Emergency stop failed: ' + e.toString());
    }
  }

  void resetEmergencyStop() => _emergencyStopped = false;

  Future<void> _recordPump(String commandId, String? decisionId, String action, String status, String reason, Map<String, dynamic> details) async {
    await audit.record(IrrigationAuditRecord(
      id: 'pump_' + commandId + '_' + action + '_' + DateTime.now().microsecondsSinceEpoch.toString(),
      type: IrrigationAuditType.pumpAction, decisionId: decisionId, commandId: commandId,
      action: action, status: status, reason: reason, timestamp: DateTime.now(), details: details,
    ));
  }

  Future<PumpCommandResult> _reject(String commandId, String? decisionId, String reason) async {
    await _recordPump(commandId, decisionId, 'command_rejected', 'rejected', reason, {});
    return PumpCommandResult(accepted: false, commandId: commandId, message: reason);
  }
}