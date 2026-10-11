import '../services/crop_growth_stage_service.dart';

enum IrrigationMode { recommendationOnly, automatic, manual }

extension IrrigationModeX on IrrigationMode {
  String get label {
    switch (this) {
      case IrrigationMode.recommendationOnly:
        return 'Recommendation only';
      case IrrigationMode.automatic:
        return 'Automatic';
      case IrrigationMode.manual:
        return 'Manual';
    }
  }
}

class RecentIrrigation {
  final DateTime? startedAt;
  final Duration duration;
  final bool completed;

  const RecentIrrigation({
    this.startedAt,
    this.duration = Duration.zero,
    this.completed = true,
  });

  bool get hasOccurred => startedAt != null;
}

class IrrigationInput {
  final double? soilMoisture;
  final int cropAgeDays;
  final CropGrowthStage growthStage;
  final double? temperature;
  final double? humidity;
  final double? rainfall;
  final String weatherContext;
  final double? forecastPrecipitation24h;
  final double? forecastPrecipitationProbability24h;
  final double? forecastEt024h;
  final RecentIrrigation recentIrrigation;
  final DateTime observedAt;

  const IrrigationInput({
    required this.soilMoisture,
    required this.cropAgeDays,
    required this.growthStage,
    required this.temperature,
    required this.humidity,
    required this.rainfall,
    required this.weatherContext,
    this.forecastPrecipitation24h,
    this.forecastPrecipitationProbability24h,
    this.forecastEt024h,
    required this.recentIrrigation,
    required this.observedAt,
  });

  bool get isValid =>
      cropAgeDays >= 0 &&
      _valid(soilMoisture, 0, 100) &&
      _valid(temperature, -50, 70) &&
      _valid(humidity, 0, 100) &&
      _valid(rainfall, 0, 2000);

  bool _valid(double? value, double min, double max) =>
      value == null || (value >= min && value <= max);
}

class IrrigationDecision {
  final String decisionId;
  final IrrigationMode mode;
  final bool irrigationRecommended;
  final double confidence;
  final String reason;
  final Duration suggestedDuration;
  final List<String> factors;
  final DateTime createdAt;

  const IrrigationDecision({
    required this.decisionId,
    required this.mode,
    required this.irrigationRecommended,
    required this.confidence,
    required this.reason,
    required this.suggestedDuration,
    required this.factors,
    required this.createdAt,
  });

  String get decisionStrength {
    if (confidence >= 0.8) return 'Strong';
    if (confidence >= 0.6) return 'Moderate';
    return 'Weak';
  }

  Map<String, dynamic> toMap() => {
    'decisionId': decisionId,
    'mode': mode.name,
    'irrigationRecommended': irrigationRecommended,
    'confidence': confidence,
    'reason': reason,
    'suggestedDurationSeconds': suggestedDuration.inSeconds,
    'factors': factors,
    'createdAt': createdAt.toIso8601String(),
  };
}

enum IrrigationAuditType { recommendation, pumpAction }

class IrrigationAuditRecord {
  final String id;
  final IrrigationAuditType type;
  final String? decisionId;
  final String? commandId;
  final String action;
  final String status;
  final String reason;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  const IrrigationAuditRecord({
    required this.id,
    required this.type,
    this.decisionId,
    this.commandId,
    required this.action,
    required this.status,
    required this.reason,
    required this.timestamp,
    this.details = const {},
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'decisionId': decisionId,
    'commandId': commandId,
    'action': action,
    'status': status,
    'reason': reason,
    'timestamp': timestamp.toIso8601String(),
    'details': details,
  };
}
