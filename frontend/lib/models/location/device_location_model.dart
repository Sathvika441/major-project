class DeviceLocationModel {
  final double latitude;
  final double longitude;
  final String? label;
  const DeviceLocationModel({
    required this.latitude,
    required this.longitude,
    this.label,
  });
}
