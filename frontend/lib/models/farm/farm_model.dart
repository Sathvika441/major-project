import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/crop_growth_stage_service.dart';

class FarmModel {
  final String id;
  final String userId;
  final String name;
  final String location;
  final double sizeAcres;
  final String waterSource;
  final String irrigationMethod;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final String landSurveyNumber;
  final String arecanutCultivationType;
  final String soilType;
  final String villageCode;
  final String state;
  final String district;
  final String taluk;
  final String village;
  final String crop;
  final DateTime? plantingDate;
  final List<Map<String, dynamic>> plantingDateHistory;

  const FarmModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.location,
    required this.sizeAcres,
    required this.waterSource,
    required this.irrigationMethod,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.landSurveyNumber = '',
    this.arecanutCultivationType = '',
    this.soilType = '',
    this.villageCode = '',
    this.state = 'Karnataka',
    this.district = '',
    this.taluk = '',
    this.village = '',
    this.crop = 'Arecanut',
    this.plantingDate,
    this.plantingDateHistory = const [],
  });

  FarmModel copyWith({
    String? name,
    String? location,
    double? sizeAcres,
    String? waterSource,
    String? irrigationMethod,
    DateTime? updatedAt,
    bool? isActive,
    String? landSurveyNumber,
    String? arecanutCultivationType,
    String? soilType,
    String? villageCode,
    String? state,
    String? district,
    String? taluk,
    String? village,
    String? crop,
    DateTime? plantingDate,
    List<Map<String, dynamic>>? plantingDateHistory,
  }) => FarmModel(
        id: id,
        userId: userId,
        name: name ?? this.name,
        location: location ?? this.location,
        sizeAcres: sizeAcres ?? this.sizeAcres,
        waterSource: waterSource ?? this.waterSource,
        irrigationMethod: irrigationMethod ?? this.irrigationMethod,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isActive: isActive ?? this.isActive,
        landSurveyNumber: landSurveyNumber ?? this.landSurveyNumber,
        arecanutCultivationType:
            arecanutCultivationType ?? this.arecanutCultivationType,
        soilType: soilType ?? this.soilType,
        villageCode: villageCode ?? this.villageCode,
        state: state ?? this.state,
        district: district ?? this.district,
        taluk: taluk ?? this.taluk,
        village: village ?? this.village,
        crop: crop ?? this.crop,
        plantingDate: plantingDate ?? this.plantingDate,
        plantingDateHistory: plantingDateHistory ?? this.plantingDateHistory,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'location': location,
        'sizeAcres': sizeAcres,
        'waterSource': waterSource,
        'irrigationMethod': irrigationMethod,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'isActive': isActive,
        'landSurveyNumber': landSurveyNumber,
        'arecanutCultivationType': arecanutCultivationType,
        'soilType': soilType,
        'villageCode': villageCode,
        'state': state,
        'district': district,
        'taluk': taluk,
        'village': village,
        'crop': crop,
        'plantingDate': plantingDate?.toIso8601String(),
        'plantingDateHistory': plantingDateHistory,
      };

  factory FarmModel.fromMap(Map<String, dynamic> map) => FarmModel(
        id: map['id'] as String,
        userId: map['userId'] as String,
        name: map['name'] as String,
        location: map['location'] as String,
        sizeAcres: (map['sizeAcres'] as num?)?.toDouble() ?? 0.0,
        waterSource: map['waterSource'] as String? ?? 'Borewell',
        irrigationMethod: map['irrigationMethod'] as String? ?? 'Drip',
        createdAt: _readDateTime(map['createdAt']) ?? DateTime.now(),
        updatedAt: _readDateTime(map['updatedAt']),
        isActive: map['isActive'] as bool? ?? true,
        landSurveyNumber: map['landSurveyNumber'] as String? ?? '',
        arecanutCultivationType: map['arecanutCultivationType'] as String? ?? '',
        soilType: map['soilType'] as String? ?? '',
        villageCode: map['villageCode'] as String? ?? '',
        state: map['state'] as String? ?? 'Karnataka',
        district: map['district'] as String? ?? '',
        taluk: map['taluk'] as String? ?? '',
        village: map['village'] as String? ?? '',
        crop: map['crop'] as String? ?? 'Arecanut',
        plantingDate: _readDateTime(map['plantingDate']),
        plantingDateHistory: (map['plantingDateHistory'] as List?)
                ?.whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList() ??
            const [],
      );

  int? get cropAgeDays {
    final date = plantingDate;
    if (date == null) return null;
    return const CropGrowthStageService().calculate(plantingDate: date).ageDays;
  }

  double? get cropAgeYears {
    final date = plantingDate;
    if (date == null) return null;
    return const CropGrowthStageService().calculate(plantingDate: date).ageYears;
  }

  CropGrowthStage? get growthStage {
    final date = plantingDate;
    if (date == null) return null;
    return const CropGrowthStageService().calculate(plantingDate: date).stage;
  }

  String? get growthStageLabel => growthStage?.label;

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class PlotModel {
  final String id;
  final String farmId;
  final String name;
  final double areaAcres;
  final String soilType;
  final String crop;
  final DateTime plantingDate;
  final Map<String, dynamic> cropMetadata;
  final String? deviceId;
  final bool isActive;

  const PlotModel({
    required this.id,
    required this.farmId,
    required this.name,
    required this.areaAcres,
    required this.soilType,
    this.crop = 'Arecanut',
    required this.plantingDate,
    this.cropMetadata = const {},
    this.deviceId,
    this.isActive = true,
  });

  int get cropAgeDays => DateTime.now().difference(plantingDate).inDays.clamp(0, 100000);

  String get growthStage {
    final years = cropAgeDays / 365.25;
    if (years < 1) return 'Establishment';
    if (years < 3) return 'Young palm';
    if (years < 6) return 'Juvenile / pre-bearing';
    if (years < 12) return 'Bearing';
    return 'Mature bearing';
  }

  PlotModel copyWith({
    String? name,
    double? areaAcres,
    String? soilType,
    DateTime? plantingDate,
    Map<String, dynamic>? cropMetadata,
    String? deviceId,
    bool? isActive,
  }) => PlotModel(
        id: id,
        farmId: farmId,
        name: name ?? this.name,
        areaAcres: areaAcres ?? this.areaAcres,
        soilType: soilType ?? this.soilType,
        crop: crop,
        plantingDate: plantingDate ?? this.plantingDate,
        cropMetadata: cropMetadata ?? this.cropMetadata,
        deviceId: deviceId ?? this.deviceId,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'name': name,
        'areaAcres': areaAcres,
        'soilType': soilType,
        'crop': crop,
        'plantingDate': plantingDate.toIso8601String(),
        'cropMetadata': cropMetadata,
        'deviceId': deviceId,
        'isActive': isActive,
      };

  factory PlotModel.fromMap(Map<String, dynamic> map) => PlotModel(
        id: map['id'] as String,
        farmId: map['farmId'] as String,
        name: map['name'] as String,
        areaAcres: (map['areaAcres'] as num).toDouble(),
        soilType: map['soilType'] as String,
        crop: map['crop'] as String? ?? 'Arecanut',
        plantingDate: DateTime.parse(map['plantingDate'] as String),
        cropMetadata: Map<String, dynamic>.from(map['cropMetadata'] as Map? ?? {}),
        deviceId: map['deviceId'] as String?,
        isActive: map['isActive'] as bool? ?? true,
      );
}
