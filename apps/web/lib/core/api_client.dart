import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = ''})
    : _client = client ?? http.Client();
  final http.Client _client;
  final String baseUrl;

  Future<Object?> getJson(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode);
    }
    return jsonDecode(response.body);
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode);
  final int statusCode;
}
