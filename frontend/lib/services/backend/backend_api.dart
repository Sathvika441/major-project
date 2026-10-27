import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../models/farm/farm_model.dart';
import '../../models/weather/weather_model.dart';

final backendApiProvider = Provider<BackendApi>((ref) => BackendApi());

class BackendApi {
  BackendApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'BACKEND_BASE_URL',
            defaultValue: kIsWeb
                ? 'http://127.0.0.1:8000'
                : 'http://10.0.2.2:8000',
          );
  final http.Client _client;
  final String baseUrl;

  Future<Map<String, dynamic>> health() async =>
      _decode(await _client.get(Uri.parse('$baseUrl/health')));

  Future<WeatherData> getWeather(FarmModel farm) async {
    return getWeatherByPlace(
      state: farm.state,
      district: farm.district,
      taluk: farm.taluk,
      village: farm.village,
      location: farm.location,
    );
  }

  Future<WeatherData> getWeatherByPlace({
    String state = 'Karnataka',
    String district = '',
    String taluk = '',
    String village = '',
    String location = '',
  }) async {
    final q = Uri(
      queryParameters: {
        'state': state,
        'district': district,
        'taluk': taluk,
        'village': village,
        'location': location,
      },
    ).query;
    final response = await _getWeatherResponse(
      Uri.parse('$baseUrl/api/v1/weather?$q'),
    );
    return WeatherData.fromMap(_decode(response));
  }

  Future<WeatherData> getWeatherByCoordinates({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final q = Uri(
      queryParameters: {
        'state': 'Karnataka',
        'district': '',
        'taluk': '',
        'village': '',
        'location': label ?? 'Current location',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
      },
    ).query;
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/weather?$q'));
    return WeatherData.fromMap(_decode(response));
  }

  Future<http.Response> _getWeatherResponse(Uri uri) async {
    try {
      return await _client.get(uri).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const BackendApiException(
        408,
        'Weather request timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const BackendApiException(
        503,
        'Unable to reach the weather service. Check that the backend is running and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> predict(Map<String, dynamic> features) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/predict'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'features': features}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> predictImage(
    Uint8List bytes, {
    String filename = 'image.jpg',
  }) async {
    const maxImageBytes = 10 * 1024 * 1024;
    if (bytes.isEmpty)
      throw const BackendApiException(400, 'The selected image is empty.');
    if (bytes.length > maxImageBytes)
      throw const BackendApiException(
        413,
        'Image is too large. Please select an image smaller than 10 MB.',
      );
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/api/v1/predict/image'),
          )
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    final response = await http.Response.fromStream(await request.send());
    return _decode(response);
  }


  Future<Map<String, dynamic>> getIoTStatus(String deviceId) async {
    final response = await _authorizedRequest(
      'GET',
      '/api/v1/app/devices/${Uri.encodeComponent(deviceId)}/status',
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getIoTReadings(
    String deviceId, {
    int limit = 50,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/app/devices/${Uri.encodeComponent(deviceId)}/readings',
    ).replace(queryParameters: {'limit': '$limit'});
    final response = await _authorizedRequest('GET', uri.toString());
    return _decode(response);
  }

  Future<Map<String, dynamic>> setIoTControl(
    String deviceId, {
    String? mode,
    bool? pumpOn,
  }) async {
    final body = <String, dynamic>{};
    if (mode != null) body['mode'] = mode;
    if (pumpOn != null) body['pump_on'] = pumpOn;
    final response = await _authorizedRequest(
      'POST',
      '/api/v1/app/devices/${Uri.encodeComponent(deviceId)}/control',
      body: body,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> setIoTEmergencyStop(
    String deviceId, {
    required bool active,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/api/v1/app/devices/${Uri.encodeComponent(deviceId)}/emergency-stop',
      body: {'active': active},
    );
    return _decode(response);
  }

  Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const BackendApiException(401, 'Please sign in to control this device.');
    String? token;
    try {
      token = await user.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw BackendApiException(401, error.code == 'user-token-expired' ? 'Your session expired. Please sign in again.' : 'Could not refresh your Firebase session. Please sign in again.');
    }
    if (token == null || token.isEmpty) throw const BackendApiException(401, 'Could not obtain a Firebase ID token. Please sign in again.');
    final uri = path.startsWith('http') ? Uri.parse(path) : Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Authorization': 'Bearer $token', if (body != null) 'Content-Type': 'application/json'};
    switch (method) {
      case 'GET': return _client.get(uri, headers: headers);
      case 'POST': return _client.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      default: throw UnsupportedError('Unsupported authorized HTTP method: $method');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      body = {'detail': response.body};
    }
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw BackendApiException(
        response.statusCode,
        body['detail']?.toString() ?? 'Backend request failed.',
      );
    return body;
  }
}

class BackendApiException implements Exception {
  final int statusCode;
  final String message;
  const BackendApiException(this.statusCode, this.message);
  @override
  String toString() => 'BackendApiException($statusCode): $message';
}
