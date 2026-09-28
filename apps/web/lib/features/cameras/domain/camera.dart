import 'package:aegivue/features/cameras/domain/camera_connection.dart';
import 'package:aegivue/features/cameras/domain/camera_motion_config.dart';
import 'package:aegivue/features/cameras/domain/camera_recording_config.dart';

class Camera {
  const Camera({
    required this.id,
    required this.name,
    required this.enabled,
    required this.connection,
    required this.recording,
    required this.motion,
    this.runtimeState = 'offline',
  });

  final String id;
  final String name;
  final bool enabled;
  final CameraConnection connection;
  final CameraRecordingConfig recording;
  final CameraMotionConfig motion;
  final String runtimeState;

  Camera withRuntimeState(String value) => Camera(
    id: id,
    name: name,
    enabled: enabled,
    connection: connection,
    recording: recording,
    motion: motion,
    runtimeState: value,
  );

  factory Camera.fromJson(Map<String, Object?> json) => Camera(
    id: json['id']! as String,
    name: json['name']! as String,
    enabled: json['enabled']! as bool,
    connection: CameraConnection.fromJson(
      json['connection']! as Map<String, Object?>,
    ),
    recording: CameraRecordingConfig.fromJson(
      json['recording']! as Map<String, Object?>,
    ),
    motion: CameraMotionConfig.fromJson(
      json['motion']! as Map<String, Object?>,
    ),
  );
}
