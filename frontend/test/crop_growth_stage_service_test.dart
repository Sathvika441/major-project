import 'package:flutter_test/flutter_test.dart';

import '../lib/core/services/crop_growth_stage_service.dart';

void main() {
  const service = CropGrowthStageService();
  final asOf = DateTime(2026, 9, 19);

  test('derives exact crop age in days from planting date', () {
    final result = service.calculate(
      plantingDate: DateTime(2026, 9, 10),
      asOf: asOf,
    );

    expect(result.ageDays, 9);
    expect(result.stage, CropGrowthStage.establishment);
  });

  test('maps project-approved age bands deterministically', () {
    expect(
      service.calculate(
        plantingDate: DateTime(2025, 9, 19),
        asOf: asOf,
      ).stage,
      CropGrowthStage.youngPalm,
    );
    expect(
      service.calculate(
        plantingDate: DateTime(2023, 9, 19),
        asOf: asOf,
      ).stage,
      CropGrowthStage.juvenilePreBearing,
    );
    expect(
      service.calculate(
        plantingDate: DateTime(2020, 9, 19),
        asOf: asOf,
      ).stage,
      CropGrowthStage.bearing,
    );
    expect(
      service.calculate(
        plantingDate: DateTime(2014, 9, 19),
        asOf: asOf,
      ).stage,
      CropGrowthStage.matureBearing,
    );
  });

  test('rejects a future planting date', () {
    expect(
      () => service.calculate(
        plantingDate: DateTime(2026, 9, 20),
        asOf: asOf,
      ),
      throwsArgumentError,
    );
  });
}
