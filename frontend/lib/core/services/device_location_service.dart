import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceLocation {
  final double latitude;
  final double longitude;
  final String? label;
  final DateTime savedAt;
  const DeviceLocation({required this.latitude,required this.longitude,this.label,required this.savedAt});
  Map<String,dynamic> toMap()=>{'latitude':latitude,'longitude':longitude,'label':label,'savedAt':savedAt.toIso8601String()};
  factory DeviceLocation.fromMap(Map<String,dynamic> m)=>DeviceLocation(latitude:(m['latitude'] as num).toDouble(),longitude:(m['longitude'] as num).toDouble(),label:m['label']?.toString(),savedAt:DateTime.tryParse(m['savedAt']?.toString()??'')??DateTime.now());
}

final deviceLocationServiceProvider=Provider<DeviceLocationService>((ref)=>DeviceLocationService());

class DeviceLocationService {
  static const _key='arecasmart_last_device_location';
  static const _placeKey='arecasmart_last_weather_place';

  Future<DeviceLocation?> resolveCurrentLocation() async {
    if (kIsWeb) {
      return _resolve();
    }
    return _resolve();
  }

  Future<DeviceLocation?> _resolve() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return loadLastLocation();
      var permission=await Geolocator.checkPermission();
      if (permission==LocationPermission.denied) permission=await Geolocator.requestPermission();
      if (permission==LocationPermission.denied || permission==LocationPermission.deniedForever) return loadLastLocation();
      final position=await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.balanced,timeLimit: Duration(seconds: 12)));
      final value=DeviceLocation(latitude:position.latitude,longitude:position.longitude,savedAt:DateTime.now());
      await saveLastLocation(value);
      return value;
    } catch (_) {
      return loadLastLocation();
    }
  }

  Future<void> saveLastLocation(DeviceLocation value) async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(_key,jsonEncode(value.toMap()));
  }

  Future<void> saveLastWeatherPlace({required String district,required String taluk,required String village}) async { final prefs=await SharedPreferences.getInstance(); await prefs.setString(_placeKey,jsonEncode({'district':district,'taluk':taluk,'village':village})); }
  Future<Map<String,String>?> loadLastWeatherPlace() async { final prefs=await SharedPreferences.getInstance(); final raw=prefs.getString(_placeKey); if(raw==null||raw.isEmpty)return null; try{final m=Map<String,dynamic>.from(jsonDecode(raw) as Map);return {'district':m['district']?.toString()??'','taluk':m['taluk']?.toString()??'','village':m['village']?.toString()??''};}catch(_){return null;} }

  Future<DeviceLocation?> loadLastLocation() async {
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString(_key);
    if(raw==null||raw.isEmpty)return null;
    try{return DeviceLocation.fromMap(jsonDecode(raw) as Map<String,dynamic>);}catch(_){return null;}
  }
}
