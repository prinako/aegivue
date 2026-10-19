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

  test(
    'sends selected camera IDs as a stable comma-separated filter',
    () async {
      final api = _FakeApiClient();
      final repository = RecordingRepository(api);

      await repository.listPage(cameraIds: {'garage', 'front-door'});

      final query = Uri.parse(api.requestedPath!).queryParameters;
      expect(query['cameraIds'], 'front-door,garage');
    },
  );

  test('loads lightweight timeline intervals with UTC bounds', () async {
    final api = _FakeApiClient(timeline: true);
    final repository = RecordingRepository(api);

    final items = await repository.timeline(
      from: DateTime.parse('2026-10-18T00:00:00-03:00'),
      to: DateTime.parse('2026-10-19T00:00:00-03:00'),
      cameraIds: {'garage', 'front-door'},
    );

    final uri = Uri.parse(api.requestedPath!);
    expect(uri.path, '/api/v1/recordings/timeline');
    expect(uri.queryParameters, {
      'from': '2026-10-18T03:00:00.000Z',
      'to': '2026-10-19T03:00:00.000Z',
      'cameraIds': 'front-door,garage',
    });
    expect(items.single.recordingId, 'recording-1');
    expect(items.single.cameraId, 'front-door');
  });

  test('loads complete recording details for timeline playback', () async {
    final api = _FakeApiClient(recording: true);
    final repository = RecordingRepository(api);

    final recording = await repository.find('recording-1');

    expect(api.requestedPath, '/api/v1/recordings/recording-1');
    expect(recording.id, 'recording-1');
    expect(recording.playbackUrl, '/recording-1.mp4');
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.timeline = false, this.recording = false});

  final bool timeline;
  final bool recording;
  String? requestedPath;

  @override
  Future<Object?> getJson(String path) async {
    requestedPath = path;
    if (timeline) {
      return {
        'items': [
          {
            'recordingId': 'recording-1',
            'cameraId': 'front-door',
            'startTime': '2026-10-18T12:00:00.000Z',
            'endTime': '2026-10-18T12:05:00.000Z',
          },
        ],
      };
    }
    if (recording) {
      return {
        'id': 'recording-1',
        'cameraId': 'front-door',
        'startTime': '2026-10-18T12:00:00.000Z',
        'endTime': '2026-10-18T12:05:00.000Z',
        'container': 'mp4',
        'playbackUrl': '/recording-1.mp4',
      };
    }
    return {
      'items': <Object?>[],
      'page': 1,
      'pageSize': 25,
      'totalItems': 0,
      'totalPages': 0,
    };
  }
}
