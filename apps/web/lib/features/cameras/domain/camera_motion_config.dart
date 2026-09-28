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
