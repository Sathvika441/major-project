import 'dart:convert';

class FarmProfileModel {
  final String userId;
  final String name;
  final String phone;
  final String location;
  final String language;
  final bool notificationsEnabled;
  final String farmName;
  final double farmSizeAcres;
  final String waterSource;
  final String irrigationMethod;
  final String crop;
  final DateTime plantingDate;

  const FarmProfileModel({
    required this.userId,
    required this.name,
    required this.phone,
    required this.location,
    required this.language,
    required this.notificationsEnabled,
    required this.farmName,
    required this.farmSizeAcres,
    required this.waterSource,
    required this.irrigationMethod,
    required this.crop,
    required this.plantingDate,
  });

  int get cropAgeDays => DateTime.now().difference(plantingDate).inDays.clamp(0, 100000);

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'phone': phone,
        'location': location,
        'language': language,
        'notificationsEnabled': notificationsEnabled,
        'farmName': farmName,
        'farmSizeAcres': farmSizeAcres,
        'waterSource': waterSource,
        'irrigationMethod': irrigationMethod,
        'crop': crop,
        'plantingDate': plantingDate.toIso8601String(),
      };

  String toJson() => jsonEncode(toMap());
}
