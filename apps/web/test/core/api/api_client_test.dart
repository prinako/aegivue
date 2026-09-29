import 'dart:typed_data';

import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/core/api/api_exception.dart';
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

  test('preserves the HTTP failure when message is not a string', () async {
    final dio = Dio()
      ..httpClientAdapter = _RecordingAdapter(
        statusCode: 502,
        body: '{"message":123}',
      );
    final api = ApiClient(client: dio);

    await expectLater(
      api.getJson('/api/v1/cameras'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 502)
            .having((error) => error.message, 'message', '123'),
      ),
    );
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, this.body = '{}'});

  final int statusCode;
  final String body;
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
