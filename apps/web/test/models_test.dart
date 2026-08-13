import 'package:flutter_test/flutter_test.dart';
import 'package:vigilo_web/features/recordings/domain/recording.dart';

void main() {
  test('recording parses API contract', () {
    final item = Recording.fromJson({
      'id': 'recording-id',
      'cameraId': 'camera-id',
      'startTime': '2026-08-13T14:20:00.000Z',
      'container': 'mp4',
      'playbackUrl': '/media',
    });
    expect(item.cameraId, 'camera-id');
    expect(item.startTime.isUtc, isTrue);
  });
}
