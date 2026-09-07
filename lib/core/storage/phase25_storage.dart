import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Phase25Storage {
  final SharedPreferences prefs;
  Phase25Storage(this.prefs);

  static Future<Phase25Storage> init() async =>
      Phase25Storage(await SharedPreferences.getInstance());

  Future<void> saveJson(String key, Map<String, dynamic> value) async =>
      prefs.setString(key, jsonEncode(value));

  Map<String, dynamic>? readJson(String key) {
    final value = prefs.getString(key);
    if (value == null) return null;
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  List<Map<String, dynamic>> readList(String key) {
    final value = prefs.getString(key);
    if (value == null || value.isEmpty) return [];
    return List<Map<String, dynamic>>.from(
      (jsonDecode(value) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> value) =>
      prefs.setString(key, jsonEncode(value));
}
