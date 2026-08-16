import 'dart:convert';
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? client, this.baseUrl = ''}) : _client = client ?? Dio();
  final Dio _client;
  final String baseUrl;

  Future<Object?> getJson(String path) async => _request('GET', path);

  Future<Object?> postJson(String path, {Object? data}) async =>
      _request('POST', path, data: data);

  Future<Object?> patchJson(String path, {Object? data}) async =>
      _request('PATCH', path, data: data);

  Future<Object?> _request(String method, String path, {Object? data}) async {
    final response = await _client.request<Object?>(
      '$baseUrl$path',
      data: data,
      options: Options(
        method: method,
        validateStatus: (_) => true,
        headers: method == 'GET'
            ? const {
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
              }
            : null,
      ),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiException(statusCode, _message(response.data));
    }
    final body = response.data;
    return body is String && body.isNotEmpty ? jsonDecode(body) : body;
  }

  String? _message(Object? data) {
    if (data is Map<String, Object?>) return data['message'] as String?;
    if (data is Map) return data['message']?.toString();
    return null;
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, [this.message]);
  final int statusCode;
  final String? message;

  @override
  String toString() => message ?? 'Request failed with status $statusCode';
}
