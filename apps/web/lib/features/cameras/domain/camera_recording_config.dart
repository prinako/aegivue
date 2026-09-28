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
