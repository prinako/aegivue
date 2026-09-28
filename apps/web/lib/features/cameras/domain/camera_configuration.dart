import 'package:aegivue/features/cameras/domain/camera.dart';

class CameraConfiguration {
  const CameraConfiguration({
    required this.id,
    required this.name,
    required this.enabled,
    required this.host,
    required this.port,
    required this.mainStream,
    required this.recordingEnabled,
    required this.recordingMode,
    required this.preEventSeconds,
    required this.postEventSeconds,
    required this.motionEnabled,
    required this.motionStream,
    required this.motionFps,
    required this.motionSensitivity,
    this.recordingRetentionDays,
    this.username,
    this.password,
    this.subStream,
  });

  final String id;
  final String name;
  final bool enabled;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final String mainStream;
  final String? subStream;
  final bool recordingEnabled;
  final String recordingMode;
  final int preEventSeconds;
  final int postEventSeconds;
  final int? recordingRetentionDays;
  final bool motionEnabled;
  final String motionStream;
  final double motionFps;
  final double motionSensitivity;

  Map<String, Object?> toJson({required bool includeId}) => {
    if (includeId) 'id': id,
    'name': name,
    'enabled': enabled,
    'connection': {
      'protocol': 'rtsp',
      'host': host,
      'port': port,
      if (username != null && username!.isNotEmpty) 'username': username,
      if (password != null && password!.isNotEmpty) 'password': password,
      'mainStream': mainStream,
      if (subStream != null && subStream!.isNotEmpty) 'subStream': subStream,
    },
    'recording': {
      'enabled': recordingEnabled,
      'mode': recordingMode,
      'preEventSeconds': preEventSeconds,
      'postEventSeconds': postEventSeconds,
      'retentionDays': recordingRetentionDays,
    },
    'motion': {
      'enabled': motionEnabled,
      'stream': motionStream,
      'fps': motionFps,
      'sensitivity': motionSensitivity,
    },
  };

  factory CameraConfiguration.fromCamera(Camera camera) => CameraConfiguration(
    id: camera.id,
    name: camera.name,
    enabled: camera.enabled,
    host: camera.connection.host,
    port: camera.connection.port,
    username: camera.connection.username,
    mainStream: camera.connection.mainStream,
    subStream: camera.connection.subStream,
    recordingEnabled: camera.recording.enabled,
    recordingMode: camera.recording.mode,
    preEventSeconds: camera.recording.preEventSeconds,
    postEventSeconds: camera.recording.postEventSeconds,
    recordingRetentionDays: camera.recording.retentionDays,
    motionEnabled: camera.motion.enabled,
    motionStream: camera.motion.stream,
    motionFps: camera.motion.fps,
    motionSensitivity: camera.motion.sensitivity,
  );
}
