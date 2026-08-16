import 'dart:convert';

import 'package:aegivue/core/api/api_exception.dart';
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? client, this.baseUrl = ''}) : _client = client ?? Dio();

  final Dio _client;
  final String baseUrl;

  Future<Object?> getJson(String path) => _request('GET', path);

  Future<Object?> postJson(String path, {Object? data}) =>
      _request('POST', path, data: data);

  Future<Object?> patchJson(String path, {Object? data}) =>
      _request('PATCH', path, data: data);

  Future<Object?> _request(String method, String path, {Object? data}) async {
    try {
      final response = await _client.request<Object?>(
        '$baseUrl$path',
        data: data,
        options: Options(method: method, validateStatus: (_) => true),
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        throw ApiException(statusCode, _message(response.data));
      }
      final body = response.data;
      return body is String && body.isNotEmpty ? jsonDecode(body) : body;
    } on DioException catch (error) {
      throw ApiException(
        error.response?.statusCode,
        _message(error.response?.data) ?? error.message,
        error,
      );
    }
  }

  String? _message(Object? data) {
    if (data is Map<String, Object?>) return data['message'] as String?;
    if (data is Map) return data['message']?.toString();
    return null;
  }
}
