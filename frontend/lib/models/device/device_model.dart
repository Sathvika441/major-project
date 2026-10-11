enum DeviceConnectionState { online, offline, stale, unknown }

class SensorReading {
  final double? soilMoisture;
  final double? temperature;
  final double? humidity;
  final double? rainfall;
  final DateTime timestamp;

  const SensorReading({
    this.soilMoisture,
    this.temperature,
    this.humidity,
    this.rainfall,
    required this.timestamp,
  });

  bool get isValid =>
      _valid(soilMoisture, 0, 100) &&
      _valid(temperature, -50, 70) &&
      _valid(humidity, 0, 100) &&
      _valid(rainfall, 0, 2000);

  bool _valid(double? value, double min, double max) =>
      value == null || (value >= min && value <= max);

  Map<String, dynamic> toMap() => {
    'soilMoisture': soilMoisture,
    'temperature': temperature,
    'humidity': humidity,
    'rainfall': rainfall,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SensorReading.fromMap(Map<String, dynamic> map) => SensorReading(
    soilMoisture: (map['soilMoisture'] as num?)?.toDouble(),
    temperature: (map['temperature'] as num?)?.toDouble(),
    humidity: (map['humidity'] as num?)?.toDouble(),
    rainfall: (map['rainfall'] as num?)?.toDouble(),
    timestamp: DateTime.parse(map['timestamp'] as String),
  );
}

class DeviceModel {
  final String id;
  final String userId;
  final String farmId;
  final String plotId;
  final String deviceId;
  final String name;
  final DateTime lastSeen;
  final SensorReading? latestReading;
  final bool isActive;

  const DeviceModel({
    required this.id,
    required this.userId,
    required this.farmId,
    required this.plotId,
    required this.deviceId,
    required this.name,
    required this.lastSeen,
    this.latestReading,
    this.isActive = true,
  });

  DeviceConnectionState get connectionState {
    if (!isActive || latestReading == null)
      return DeviceConnectionState.unknown;
    final age = DateTime.now().difference(lastSeen);
    if (age <= const Duration(minutes: 5)) return DeviceConnectionState.online;
    if (age <= const Duration(hours: 1)) return DeviceConnectionState.stale;
    return DeviceConnectionState.offline;
  }

  DeviceModel copyWith({
    String? farmId,
    String? plotId,
    String? name,
    DateTime? lastSeen,
    SensorReading? latestReading,
    bool? isActive,
  }) => DeviceModel(
    id: id,
    userId: userId,
    farmId: farmId ?? this.farmId,
    plotId: plotId ?? this.plotId,
    deviceId: deviceId,
    name: name ?? this.name,
    lastSeen: lastSeen ?? this.lastSeen,
    latestReading: latestReading ?? this.latestReading,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'farmId': farmId,
    'plotId': plotId,
    'deviceId': deviceId,
    'name': name,
    'lastSeen': lastSeen.toIso8601String(),
    'latestReading': latestReading?.toMap(),
    'isActive': isActive,
  };

  factory DeviceModel.fromMap(Map<String, dynamic> map) => DeviceModel(
    id: map['id'] as String,
    userId: map['userId'] as String,
    farmId: map['farmId'] as String,
    plotId: map['plotId'] as String,
    deviceId: map['deviceId'] as String,
    name: map['name'] as String,
    lastSeen: DateTime.parse(map['lastSeen'] as String),
    latestReading: map['latestReading'] != null
        ? SensorReading.fromMap(
            Map<String, dynamic>.from(map['latestReading'] as Map),
          )
        : null,
    isActive: map['isActive'] as bool? ?? true,
  );
}
