import 'dart:math' as math;

import '../services/crop_growth_stage_service.dart';
import 'irrigation_models.dart';

class IrrigationDecisionEngine {
  const IrrigationDecisionEngine();

  IrrigationDecision decide({
    required IrrigationInput input,
    required IrrigationMode mode,
    DateTime? now,
  }) {
    final createdAt = now ?? DateTime.now();
    final decisionId = 'decision_' + createdAt.microsecondsSinceEpoch.toString();

    if (!input.isValid) {
      return IrrigationDecision(
        decisionId: decisionId, mode: mode, irrigationRecommended: false,
        confidence: 1,
        reason: 'Input validation failed; irrigation was blocked for safety.',
        suggestedDuration: Duration.zero,
        factors: const ['Invalid or out-of-range sensor input'],
        createdAt: createdAt,
      );
    }

    final factors = <String>[];
    var score = 0.0;
    final moisture = input.soilMoisture;
    if (moisture == null) {
      factors.add('Soil moisture is unavailable');
    } else if (moisture < 20) {
      score += 0.42; factors.add('Very dry soil');
    } else if (moisture < 35) {
      score += 0.25; factors.add('Dry soil');
    } else if (moisture < 50) {
      score += 0.08; factors.add('Moderately dry soil');
    } else if (moisture > 80) {
      score -= 0.42; factors.add('High soil moisture');
    } else {
      factors.add('Soil moisture is not strongly indicating irrigation');
    }

    final ageYears = input.cropAgeDays / 365.25;
    if (ageYears < 1) {
      score += 0.08;
      factors.add('Crop age is under 1 year');
    } else if (ageYears < 3) {
      score += 0.05;
      factors.add('Crop age is 1-3 years');
    } else if (ageYears < 6) {
      score += 0.03;
      factors.add('Crop age is 3-6 years');
    } else if (ageYears < 12) {
      score += 0.06;
      factors.add('Crop age is 6-12 years');
    } else {
      score += 0.04;
      factors.add('Crop age is 12+ years');
    }

    switch (input.growthStage) {
      case CropGrowthStage.establishment:
        score += 0.22; factors.add('Establishment stage increases water-stress sensitivity');
      case CropGrowthStage.youngPalm:
        score += 0.18; factors.add('Young palm stage increases water-demand sensitivity');
      case CropGrowthStage.juvenilePreBearing:
        score += 0.12; factors.add('Pre-bearing stage contributes to the water-demand score');
      case CropGrowthStage.bearing:
        score += 0.16; factors.add('Bearing stage contributes to the water-demand score');
      case CropGrowthStage.matureBearing:
        score += 0.10; factors.add('Mature bearing stage contributes to the water-demand score');
    }

    final temperature = input.temperature;
    if (temperature != null) {
      if (temperature >= 36) {
        score += 0.18; factors.add('High temperature increases evapotranspiration pressure');
      } else if (temperature >= 32) {
        score += 0.08; factors.add('Warm conditions increase water demand');
      }
    }
    if (input.humidity != null && input.humidity! < 45) {
      score += 0.10; factors.add('Low humidity increases atmospheric demand');
    }
    final rainfall = input.rainfall;
    if (rainfall != null) {
      if (rainfall >= 20) {
        score -= 0.40; factors.add('Recent/heavy rainfall reduces irrigation need');
      } else if (rainfall >= 5) {
        score -= 0.12; factors.add('Recent rainfall reduces irrigation need');
      }
    }
    final weather = input.weatherContext.trim().toLowerCase();
    if (weather.contains('rain') || weather.contains('storm') || weather.contains('wet')) {
      score -= 0.20; factors.add('Wet weather context suppresses irrigation');
    } else if (weather.contains('dry') || weather.contains('heat') || weather.contains('hot')) {
      score += 0.12; factors.add('Dry/hot weather context increases water demand');
    }

    final forecastRain = input.forecastPrecipitation24h;
    if (forecastRain != null) {
      if (forecastRain >= 8) {
        score -= 0.28;
        factors.add('Meaningful rainfall is forecast in the next 24 hours');
      } else if (forecastRain >= 3) {
        score -= 0.12;
        factors.add('Rainfall is forecast in the next 24 hours');
      }
    }

    final forecastProbability = input.forecastPrecipitationProbability24h;
    if (forecastProbability != null) {
      if (forecastProbability >= 70 && (forecastRain ?? 0) >= 3) {
        score -= 0.18;
        factors.add('High probability of rain supports delaying irrigation');
      } else if (forecastProbability >= 50 && (forecastRain ?? 0) >= 1) {
        score -= 0.08;
        factors.add('Rain probability is elevated in the next 24 hours');
      }
    }

    final forecastEt0 = input.forecastEt024h;
    if (forecastEt0 != null) {
      if (forecastEt0 >= 5) {
        score += 0.10;
        factors.add('High reference evapotranspiration increases water demand');
      } else if (forecastEt0 >= 3) {
        score += 0.05;
        factors.add('Reference evapotranspiration adds moderate water demand');
      }
    }

    final recent = input.recentIrrigation;
    if (recent.hasOccurred) {
      final elapsed = createdAt.difference(recent.startedAt!);
      if (elapsed.isNegative) {
        score -= 0.25; factors.add('Recent irrigation timestamp is in the future');
      } else if (elapsed < const Duration(hours: 12)) {
        score -= 0.35; factors.add('Irrigation occurred within the last 12 hours');
      } else if (elapsed < const Duration(hours: 24)) {
        score -= 0.18; factors.add('Irrigation occurred within the last 24 hours');
      }
    }

    final clampedScore = score.clamp(-0.6, 1.0).toDouble();
    final recommended = clampedScore >= 0.30;
    final minutes = recommended ? (10 + math.max(0, clampedScore - 0.30) * 20).round() : 0;
    final suggestedDuration = Duration(minutes: minutes.clamp(0, 30));
    final confidence = recommended
        ? (0.55 + clampedScore * 0.35).clamp(0.55, 0.95).toDouble()
        : (0.55 + (0.30 - clampedScore).abs() * 0.30).clamp(0.55, 0.95).toDouble();
    final topFactors = factors.take(3).join('; ');
    final reason = recommended
        ? 'Irrigation is recommended because multiple signals indicate water demand: ' + topFactors + '.'
        : 'Irrigation is not recommended because the combined conditions do not indicate sufficient water demand: ' + topFactors + '.';

    return IrrigationDecision(
      decisionId: decisionId, mode: mode, irrigationRecommended: recommended,
      confidence: confidence, reason: reason, suggestedDuration: suggestedDuration,
      factors: List.unmodifiable(factors), createdAt: createdAt,
    );
  }
}