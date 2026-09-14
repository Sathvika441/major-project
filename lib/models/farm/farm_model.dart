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
      };

  factory FarmModel.fromMap(Map<String, dynamic> map) => FarmModel(
        id: map['id'] as String,
        userId: map['userId'] as String,
        name: map['name'] as String,
        location: map['location'] as String,
        sizeAcres: (map['sizeAcres'] as num?)?.toDouble() ?? 0.0,
        waterSource: map['waterSource'] as String? ?? 'Borewell',
        irrigationMethod: map['irrigationMethod'] as String? ?? 'Drip',
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                DateTime.now(),
        updatedAt: map['updatedAt'] != null
            ? DateTime.tryParse(map['updatedAt'] as String)
            : null,
        isActive: map['isActive'] as bool? ?? true,
        landSurveyNumber: map['landSurveyNumber'] as String? ?? '',
        arecanutCultivationType: map['arecanutCultivationType'] as String? ?? '',
        soilType: map['soilType'] as String? ?? '',
        villageCode: map['villageCode'] as String? ?? '',
      );
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
