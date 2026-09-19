import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/device/device_model.dart';

final simulatedSensorProvider = Provider<SimulatedSensorService>((ref) {
  return SimulatedSensorService();
});

class SimulatedSensorService {
  final Random _random = Random();

  SensorReading generateReading() {
    return SensorReading(
      soilMoisture: 15 + _random.nextDouble() * 55,
      temperature: 24 + _random.nextDouble() * 14,
      humidity: 45 + _random.nextDouble() * 40,
      rainfall: _random.nextDouble() * 8,
      timestamp: DateTime.now(),
    );
  }
}
