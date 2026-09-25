import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/farm/farm_model.dart';
import '../../models/weather/weather_model.dart';
import 'package:http/http.dart' as http;

final backendApiProvider = Provider<BackendApi>((ref) => BackendApi());

class BackendApi {
  BackendApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? const String.fromEnvironment(
          'BACKEND_BASE_URL',
          defaultValue: kIsWeb
              ? 'http://127.0.0.1:8000'
              : 'http://10.0.2.2:8000',
        );

  final http.Client _client;
  final String baseUrl;

  Future<Map<String, dynamic>> health() async {
    final response = await _client.get(Uri.parse('$baseUrl/health'));
    return _decode(response);
  }

  Future<WeatherData> getWeather(FarmModel farm) async {
    final query = Uri(queryParameters: {
      'state': farm.state,
      'district': farm.district,
      'taluk': farm.taluk,
      'village': farm.village,
    }).query;

    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/weather?$query'),
    );
    return WeatherData.fromMap(_decode(response));
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

    if (bytes.isEmpty) {
      throw const BackendApiException(
        400,
        'The selected image is empty.',
      );
    }

    if (bytes.length > maxImageBytes) {
      throw const BackendApiException(
        413,
        'Image is too large. Please select an image smaller than 10 MB.',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/predict/image'),
    )
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(
        jsonDecode(response.body) as Map,
      );
    } catch (_) {
      body = {'detail': response.body};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        response.statusCode,
        body['detail']?.toString() ?? 'Backend request failed.',
      );
    }

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
