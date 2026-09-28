import 'dart:typed_data';

import 'package:aegivue/core/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applies finite timeouts to requests by default', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(client: dio);

    await api.getJson('/api/v1/cameras');

    expect(adapter.options!.connectTimeout, const Duration(seconds: 10));
    expect(adapter.options!.receiveTimeout, const Duration(seconds: 30));
    expect(adapter.options!.sendTimeout, const Duration(seconds: 10));
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
