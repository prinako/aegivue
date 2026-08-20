class CameraConnection {
  const CameraConnection({
    required this.host,
    required this.port,
    required this.mainStream,
    this.username,
    this.subStream,
  });

  final String host;
  final int port;
  final String? username;
  final String mainStream;
  final String? subStream;

  factory CameraConnection.fromJson(Map<String, Object?> json) =>
      CameraConnection(
        host: json['host']! as String,
        port: (json['port']! as num).toInt(),
        username: json['username'] as String?,
        mainStream: json['mainStream']! as String,
        subStream: json['subStream'] as String?,
      );
}

class CameraRecordingConfig {
  const CameraRecordingConfig({
    required this.enabled,
    required this.mode,
    required this.preEventSeconds,
    required this.postEventSeconds,
    this.retentionDays,
  });

  final bool enabled;
  final String mode;
  final int preEventSeconds;
  final int postEventSeconds;
  final int? retentionDays;

  factory CameraRecordingConfig.fromJson(Map<String, Object?> json) =>
      CameraRecordingConfig(
        enabled: json['enabled']! as bool,
        mode: json['mode']! as String,
        preEventSeconds: (json['preEventSeconds']! as num).toInt(),
        postEventSeconds: (json['postEventSeconds']! as num).toInt(),
        retentionDays: (json['retentionDays'] as num?)?.toInt(),
      );
}

class CameraMotionConfig {
  const CameraMotionConfig({
    required this.enabled,
    required this.stream,
    required this.fps,
    required this.sensitivity,
  });

  final bool enabled;
  final String stream;
  final double fps;
  final double sensitivity;

  factory CameraMotionConfig.fromJson(Map<String, Object?> json) =>
      CameraMotionConfig(
        enabled: json['enabled']! as bool,
        stream: json['stream']! as String,
        fps: (json['fps']! as num).toDouble(),
        sensitivity: (json['sensitivity']! as num).toDouble(),
      );
}

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
