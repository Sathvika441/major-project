import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final backendApiProvider = Provider<BackendApi>((ref) => BackendApi());

class BackendApi {
  BackendApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? const String.fromEnvironment(
          'BACKEND_BASE_URL',
          defaultValue: 'http://10.0.2.2:8000',
        );

  final http.Client _client;
  final String baseUrl;

  Future<Map<String, dynamic>> health() async {
    final response = await _client.get(Uri.parse('$baseUrl/health'));
    return _decode(response);
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
      body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
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
