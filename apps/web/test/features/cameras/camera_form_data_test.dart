import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/domain/camera_connection.dart';
import 'package:aegivue/features/cameras/domain/camera_motion_config.dart';
import 'package:aegivue/features/cameras/domain/camera_recording_config.dart';
import 'package:aegivue/features/cameras/presentation/camera_form_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new camera form produces the documented defaults', () {
    final data = CameraFormData.fromCamera(null);
    addTearDown(data.dispose);

    data.id.text = 'front-door';
    data.name.text = 'Front Door';
    data.host.text = '192.168.1.10';
    data.mainStream.text = '/Streaming/Channels/101';

    final configuration = data.toConfiguration();

    expect(data.editing, isFalse);
    expect(configuration.port, 554);
    expect(configuration.enabled, isTrue);
    expect(configuration.recordingEnabled, isTrue);
    expect(configuration.recordingMode, 'continuous');
    expect(configuration.preEventSeconds, 5);
    expect(configuration.postEventSeconds, 15);
    expect(configuration.motionEnabled, isFalse);
    expect(configuration.motionStream, 'sub');
    expect(configuration.motionFps, 5);
    expect(configuration.motionSensitivity, 0.65);
  });

  test('edit form preserves camera values and leaves password unchanged', () {
    final data = CameraFormData.fromCamera(_camera());
    addTearDown(data.dispose);

    final configuration = data.toConfiguration();

    expect(data.editing, isTrue);
    expect(configuration.id, 'front-door');
    expect(configuration.name, 'Front Door');
    expect(configuration.host, '192.168.1.10');
    expect(configuration.username, 'operator');
    expect(configuration.password, isNull);
    expect(configuration.mainStream, '/Streaming/Channels/101');
    expect(configuration.subStream, '/Streaming/Channels/102');
    expect(configuration.recordingRetentionDays, 30);
    expect(configuration.motionSensitivity, 0.8);
  });

  test('sub-stream motion requires a configured sub stream', () {
    final data = CameraFormData.fromCamera(null);
    addTearDown(data.dispose);

    data.motionEnabled = true;
    data.motionStream = 'sub';
    expect(data.missingMotionSubStream, isTrue);

    data.subStream.text = '/Streaming/Channels/102';
    expect(data.missingMotionSubStream, isFalse);
  });
}

Camera _camera() => const Camera(
  id: 'front-door',
  name: 'Front Door',
  enabled: true,
  connection: CameraConnection(
    host: '192.168.1.10',
    port: 8554,
    username: 'operator',
    mainStream: '/Streaming/Channels/101',
    subStream: '/Streaming/Channels/102',
  ),
  recording: CameraRecordingConfig(
    enabled: true,
    mode: 'motion',
    preEventSeconds: 10,
    postEventSeconds: 20,
    retentionDays: 30,
  ),
  motion: CameraMotionConfig(
    enabled: true,
    stream: 'sub',
    fps: 8,
    sensitivity: 0.8,
  ),
);
