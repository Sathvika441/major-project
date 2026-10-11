enum CropGrowthStage {
  establishment,
  youngPalm,
  juvenilePreBearing,
  bearing,
  matureBearing,
}

extension CropGrowthStageX on CropGrowthStage {
  String get label {
    switch (this) {
      case CropGrowthStage.establishment:
        return 'Establishment';
      case CropGrowthStage.youngPalm:
        return 'Young palm';
      case CropGrowthStage.juvenilePreBearing:
        return 'Juvenile / pre-bearing';
      case CropGrowthStage.bearing:
        return 'Bearing';
      case CropGrowthStage.matureBearing:
        return 'Mature bearing';
    }
  }
}

class CropGrowthStageResult {
  final int ageDays;
  final double ageYears;
  final CropGrowthStage stage;

  const CropGrowthStageResult({
    required this.ageDays,
    required this.ageYears,
    required this.stage,
  });

  String get stageLabel => stage.label;
}

/// Deterministic agronomic stage mapping used by the project for arecanut.
///
/// The same thresholds are used by the legacy PlotModel growth-stage logic:
/// <1 year: establishment
/// 1-<3 years: young palm
/// 3-<6 years: juvenile / pre-bearing
/// 6-<12 years: bearing
/// >=12 years: mature bearing
class CropGrowthStageService {
  const CropGrowthStageService();

  CropGrowthStageResult calculate({
    required DateTime plantingDate,
    DateTime? asOf,
  }) {
    final currentDate = _dateOnly(asOf ?? DateTime.now());
    final plantedDate = _dateOnly(plantingDate);

    if (plantedDate.isAfter(currentDate)) {
      throw ArgumentError('Planting date cannot be in the future.');
    }

    final ageDays = currentDate.difference(plantedDate).inDays;
    final ageYears = ageDays / 365.25;

    final stage = switch (ageYears) {
      < 1 => CropGrowthStage.establishment,
      < 3 => CropGrowthStage.youngPalm,
      < 6 => CropGrowthStage.juvenilePreBearing,
      < 12 => CropGrowthStage.bearing,
      _ => CropGrowthStage.matureBearing,
    };

    return CropGrowthStageResult(
      ageDays: ageDays,
      ageYears: ageYears,
      stage: stage,
    );
  }

  void validatePlantingDate(DateTime plantingDate, {DateTime? asOf}) {
    calculate(plantingDate: plantingDate, asOf: asOf);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
