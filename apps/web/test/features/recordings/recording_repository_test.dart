import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lists a page without date query parameters by default', () async {
    final api = _FakeApiClient();
    final repository = RecordingRepository(api);

    await repository.listPage(page: 2, pageSize: 10);

    final uri = Uri.parse(api.requestedPath!);
    expect(uri.path, '/api/v1/recordings');
    expect(uri.queryParameters, {'page': '2', 'pageSize': '10'});
  });

  test('sends date filters as ISO-8601 UTC query parameters', () async {
    final api = _FakeApiClient();
    final repository = RecordingRepository(api);
    final from = DateTime.parse('2026-10-17T08:00:00-03:00');
    final to = DateTime.parse('2026-10-17T18:00:00-03:00');

    await repository.listPage(from: from, to: to);

    final query = Uri.parse(api.requestedPath!).queryParameters;
    expect(query['from'], '2026-10-17T11:00:00.000Z');
    expect(query['to'], '2026-10-17T21:00:00.000Z');
  });
}

class _FakeApiClient extends ApiClient {
  String? requestedPath;

  @override
  Future<Object?> getJson(String path) async {
    requestedPath = path;
    return {
      'items': <Object?>[],
      'page': 1,
      'pageSize': 25,
      'totalItems': 0,
      'totalPages': 0,
    };
  }
}
