import 'package:flutter_test/flutter_test.dart';

import '../lib/core/irrigation/irrigation_decision_engine.dart';
import '../lib/core/irrigation/irrigation_models.dart';
import '../lib/core/irrigation/pump_controller.dart';
import '../lib/core/irrigation/irrigation_audit.dart';
import '../lib/core/services/crop_growth_stage_service.dart';

void main() {
  const engine = IrrigationDecisionEngine();
  final now = DateTime(2026, 9, 19, 10);

  IrrigationInput input({
    double? moisture = 25,
    CropGrowthStage stage = CropGrowthStage.bearing,
    double? temperature = 35,
    double? humidity = 40,
    double? rainfall = 0,
    String weather = 'dry',
    RecentIrrigation recent = const RecentIrrigation(),
  }) => IrrigationInput(
        soilMoisture: moisture, cropAgeDays: 2500, growthStage: stage,
        temperature: temperature, humidity: humidity, rainfall: rainfall,
        weatherContext: weather, recentIrrigation: recent, observedAt: now,
      );

  test('decision uses multiple factors, not soil moisture alone', () {
    final dry = engine.decide(input: input(), mode: IrrigationMode.recommendationOnly, now: now);
    final wet = engine.decide(input: input(moisture: 25, rainfall: 30, weather: 'heavy rain'), mode: IrrigationMode.recommendationOnly, now: now);
    expect(dry.irrigationRecommended, isTrue);
    expect(wet.irrigationRecommended, isFalse);
    expect(dry.reason, isNotEmpty);
    expect(dry.factors.length, greaterThan(1));
  });

  test('growth stage materially changes the decision', () {
    final establishment = engine.decide(input: input(stage: CropGrowthStage.establishment, moisture: 38, temperature: 30, humidity: 60), mode: IrrigationMode.recommendationOnly, now: now);
    final mature = engine.decide(input: input(stage: CropGrowthStage.matureBearing, moisture: 38, temperature: 30, humidity: 60), mode: IrrigationMode.recommendationOnly, now: now);
    expect(establishment.confidence, isNot(equals(mature.confidence)));
    expect(establishment.suggestedDuration, isNot(equals(mature.suggestedDuration)));
  });

  test('recent irrigation suppresses a recommendation', () {
    final result = engine.decide(input: input(recent: RecentIrrigation(startedAt: now.subtract(const Duration(hours: 2)), duration: const Duration(minutes: 15))), mode: IrrigationMode.recommendationOnly, now: now);
    expect(result.irrigationRecommended, isFalse);
  });

  test('recommendation only cannot start a pump', () async {
    final audit = InMemoryIrrigationAuditLog();
    final pump = SafePumpController(driver: SimulatedPumpDriver(), audit: audit);
    final result = await pump.start(commandId: 'r1', duration: const Duration(minutes: 5), mode: IrrigationMode.recommendationOnly, confirmed: true);
    expect(result.accepted, isFalse);
  });

  test('manual start requires confirmation and respects max runtime', () async {
    final audit = InMemoryIrrigationAuditLog();
    final pump = SafePumpController(driver: SimulatedPumpDriver(), audit: audit, maxRuntime: const Duration(minutes: 10));
    final noConfirm = await pump.start(commandId: 'm1', duration: const Duration(minutes: 5), mode: IrrigationMode.manual, confirmed: false);
    expect(noConfirm.accepted, isFalse);
    final tooLong = await pump.start(commandId: 'm2', duration: const Duration(minutes: 11), mode: IrrigationMode.manual, confirmed: true);
    expect(tooLong.accepted, isFalse);
  });

  test('duplicate pump commands are blocked and audited', () async {
    final audit = InMemoryIrrigationAuditLog();
    final pump = SafePumpController(driver: SimulatedPumpDriver(), audit: audit);
    final first = await pump.start(commandId: 'd1', duration: const Duration(minutes: 1), mode: IrrigationMode.manual, confirmed: true);
    final second = await pump.start(commandId: 'd2', duration: const Duration(minutes: 1), mode: IrrigationMode.manual, confirmed: true);
    expect(first.accepted, isTrue);
    expect(second.accepted, isFalse);
    expect(audit.records.any((r) => r.status == 'rejected'), isTrue);
    await pump.emergencyStop();
  });
}