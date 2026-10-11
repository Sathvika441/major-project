import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/models/farm/farm_model.dart';
import 'package:major_proj_1/models/device/device_model.dart';

void main() {
  test('plot crop age is derived from planting date', () {
    final plantingDate = DateTime.now().subtract(const Duration(days: 120));
    final plot = PlotModel(
      id: 'p1',
      farmId: 'f1',
      name: 'Plot A',
      areaAcres: 1.0,
      soilType: 'Loamy',
      plantingDate: plantingDate,
    );
    expect(plot.cropAgeDays, inInclusiveRange(119, 121));
    expect(plot.growthStage, isNotEmpty);
  });

  test('invalid sensor values are rejected by reading validation', () {
    final reading = SensorReading(
      soilMoisture: 140,
      temperature: 30,
      humidity: 55,
      rainfall: 4,
      timestamp: DateTime.now(),
    );
    expect(reading.isValid, isFalse);
  });

  test('valid sensor values pass validation', () {
    final reading = SensorReading(
      soilMoisture: 38,
      temperature: 29,
      humidity: 70,
      rainfall: 2,
      timestamp: DateTime.now(),
    );
    expect(reading.isValid, isTrue);
  });

  test('device becomes stale after five minutes', () {
    final device = DeviceModel(
      id: 'd1',
      userId: 'u1',
      farmId: 'f1',
      plotId: 'p1',
      deviceId: 'ESP32-01',
      name: 'Field sensor',
      lastSeen: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    expect(device.connectionState, DeviceConnectionState.stale);
  });
}
