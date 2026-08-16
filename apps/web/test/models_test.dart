import 'package:flutter_test/flutter_test.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';

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

  test('camera parses editable configuration from API', () {
    final camera = Camera.fromJson({
      'id': 'front-door',
      'name': 'Front Door',
      'enabled': true,
      'connection': {
        'protocol': 'rtsp',
        'host': '192.168.30.10',
        'port': 554,
        'username': 'admin',
        'mainStream': '/stream1',
        'subStream': '/stream2',
      },
      'recording': {
        'enabled': true,
        'mode': 'continuous',
        'preEventSeconds': 5,
        'postEventSeconds': 15,
      },
      'motion': {
        'enabled': false,
        'stream': 'sub',
        'fps': 5,
        'sensitivity': 0.65,
      },
    });

    expect(camera.connection.host, '192.168.30.10');
    expect(camera.connection.mainStream, '/stream1');
    expect(camera.recording.mode, 'continuous');
  });

  test('camera update omits blank password', () {
    const configuration = CameraConfiguration(
      id: 'front-door',
      name: 'Front Door',
      enabled: true,
      host: '192.168.30.10',
      port: 554,
      username: 'admin',
      mainStream: '/stream1',
      subStream: '/stream2',
      recordingEnabled: true,
      recordingMode: 'continuous',
      preEventSeconds: 5,
      postEventSeconds: 15,
      motionEnabled: false,
      motionStream: 'sub',
      motionFps: 5,
      motionSensitivity: 0.65,
    );

    final json = configuration.toJson(includeId: false);
    final connection = json['connection']! as Map<String, Object?>;
    expect(json.containsKey('id'), isFalse);
    expect(connection.containsKey('password'), isFalse);
  });
}
