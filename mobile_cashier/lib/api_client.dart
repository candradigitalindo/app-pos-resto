import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiResult {
  final bool success;
  final String message;
  final dynamic data;
  final int statusCode;

  ApiResult({
    required this.success,
    required this.message,
    required this.data,
    required this.statusCode,
  });
}

class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;
  static const Duration _timeout = Duration(seconds: 8);

  Future<ApiResult> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  Future<ApiResult> post(String path, {Map<String, dynamic>? body}) {
    return _send('POST', path, body: body);
  }

  Future<ApiResult> put(String path, {Map<String, dynamic>? body}) {
    return _send('PUT', path, body: body);
  }

  Future<ApiResult> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1$path',
    ).replace(queryParameters: query);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      http.Response response;
      final encodedBody = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: encodedBody)
              .timeout(_timeout);
          break;
        default:
          throw StateError('Unsupported method $method');
      }

      dynamic payload;
      String message = '';
      try {
        payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic>) {
          message = payload['message']?.toString() ?? '';
        }
      } catch (_) {
        payload = null;
      }

      final success = response.statusCode >= 200 && response.statusCode < 300;
      if (payload is Map<String, dynamic> && payload['success'] is bool) {
        return ApiResult(
          success: payload['success'] as bool,
          message: message,
          data: payload['data'],
          statusCode: response.statusCode,
        );
      }

      return ApiResult(
        success: success,
        message: message,
        data: payload,
        statusCode: response.statusCode,
      );
    } catch (error) {
      return ApiResult(
        success: false,
        message: error.toString(),
        data: null,
        statusCode: 0,
      );
    }
  }
}
