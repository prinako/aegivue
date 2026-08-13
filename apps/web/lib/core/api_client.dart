import 'dart:convert';
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? client, this.baseUrl = ''}) : _client = client ?? Dio();
  final Dio _client;
  final String baseUrl;

  Future<Object?> getJson(String path) async {
    final response = await _client.get<Object?>(
      '$baseUrl$path',
      options: Options(validateStatus: (_) => true),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiException(statusCode);
    }
    final data = response.data;
    return data is String ? jsonDecode(data) : data;
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode);
  final int statusCode;
}
