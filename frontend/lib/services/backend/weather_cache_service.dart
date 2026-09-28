import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherCacheService {
  static const _key='arecasmart_weather_cache_v2';
  Future<void> save(Map<String,dynamic> value) async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(_key,jsonEncode(value));
  }
  Future<Map<String,dynamic>?> load() async {
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString(_key);
    if(raw==null||raw.isEmpty)return null;
    try{return Map<String,dynamic>.from(jsonDecode(raw) as Map);}catch(_){return null;}
  }
}
