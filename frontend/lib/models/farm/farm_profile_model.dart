import 'dart:convert';

class FarmProfileModel {
  final String userId;
  final String name;
  final String phone;
  final String location;
  final String state;
  final String district;
  final String taluk;
  final String village;
  final String villageCode;
  final String language;
  final bool notificationsEnabled;
  final String farmName;
  final double farmSizeAcres;
  final String waterSource;
  final String irrigationMethod;
  final String crop;
  final DateTime plantingDate;
  final String landSurveyNumber;
  final String arecanutCultivationType;
  final String soilType;

  const FarmProfileModel({
    required this.userId,
    required this.name,
    required this.phone,
    required this.location,
    this.state = 'Karnataka',
    this.district = '',
    this.taluk = '',
    this.village = '',
    this.villageCode = '',
    required this.language,
    required this.notificationsEnabled,
    required this.farmName,
    required this.farmSizeAcres,
    required this.waterSource,
    required this.irrigationMethod,
    required this.crop,
    required this.plantingDate,
    this.landSurveyNumber = '',
    this.arecanutCultivationType = '',
    this.soilType = '',
  });

  int get cropAgeDays =>
      DateTime.now().difference(plantingDate).inDays.clamp(0, 100000);

  FarmProfileModel copyWith({
    String? userId,
    String? name,
    String? phone,
    String? location,
    String? state,
    String? district,
    String? taluk,
    String? village,
    String? villageCode,
    String? language,
    bool? notificationsEnabled,
    String? farmName,
    double? farmSizeAcres,
    String? waterSource,
    String? irrigationMethod,
    String? crop,
    DateTime? plantingDate,
    String? landSurveyNumber,
    String? arecanutCultivationType,
    String? soilType,
  }) {
    return FarmProfileModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      state: state ?? this.state,
      district: district ?? this.district,
      taluk: taluk ?? this.taluk,
      village: village ?? this.village,
      villageCode: villageCode ?? this.villageCode,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      farmName: farmName ?? this.farmName,
      farmSizeAcres: farmSizeAcres ?? this.farmSizeAcres,
      waterSource: waterSource ?? this.waterSource,
      irrigationMethod: irrigationMethod ?? this.irrigationMethod,
      crop: crop ?? this.crop,
      plantingDate: plantingDate ?? this.plantingDate,
      landSurveyNumber: landSurveyNumber ?? this.landSurveyNumber,
      arecanutCultivationType:
          arecanutCultivationType ?? this.arecanutCultivationType,
      soilType: soilType ?? this.soilType,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'name': name,
    'phone': phone,
    'location': location,
    'state': state,
    'district': district,
    'taluk': taluk,
    'village': village,
    'villageCode': villageCode,
    'language': language,
    'notificationsEnabled': notificationsEnabled,
    'farmName': farmName,
    'farmSizeAcres': farmSizeAcres,
    'waterSource': waterSource,
    'irrigationMethod': irrigationMethod,
    'crop': crop,
    'plantingDate': plantingDate.toIso8601String(),
    'landSurveyNumber': landSurveyNumber,
    'arecanutCultivationType': arecanutCultivationType,
    'soilType': soilType,
  };

  factory FarmProfileModel.fromMap(Map<String, dynamic> map) {
    final st = (map['state'] as String?) ?? 'Karnataka';
    final dt = (map['district'] as String?) ?? '';
    final tl = (map['taluk'] as String?) ?? '';
    final vl = (map['village'] as String?) ?? '';
    var loc = map['location'] as String? ?? '';
    if (loc.isEmpty) {
      final parts = <String>[];
      if (vl.isNotEmpty) parts.add(vl);
      if (tl.isNotEmpty) parts.add(tl);
      if (dt.isNotEmpty) parts.add(dt);
      if (st.isNotEmpty) parts.add(st);
      loc = parts.join(', ');
    }
    return FarmProfileModel(
      userId: map['userId'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      location: loc,
      state: st,
      district: dt,
      taluk: tl,
      village: vl,
      villageCode: map['villageCode'] as String? ?? '',
      language: map['language'] as String? ?? 'English',
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      farmName: map['farmName'] as String? ?? '',
      farmSizeAcres: (map['farmSizeAcres'] as num?)?.toDouble() ?? 0.0,
      waterSource: map['waterSource'] as String? ?? 'Borewell',
      irrigationMethod: map['irrigationMethod'] as String? ?? 'Drip',
      crop: map['crop'] as String? ?? 'Arecanut',
      plantingDate:
          DateTime.tryParse(map['plantingDate'] as String? ?? '') ??
          DateTime.now(),
      landSurveyNumber: map['landSurveyNumber'] as String? ?? '',
      arecanutCultivationType: map['arecanutCultivationType'] as String? ?? '',
      soilType: map['soilType'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FarmProfileModel.fromJson(String source) =>
      FarmProfileModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
