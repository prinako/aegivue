class Recording {
  const Recording({
    required this.id,
    required this.cameraId,
    required this.startTime,
    required this.container,
    required this.playbackUrl,
    this.endTime,
    this.fileSize,
    this.durationMs,
    this.videoCodec,
    this.audioCodec,
    this.width,
    this.height,
    this.fps,
  });

  final String id;
  final String cameraId;
  final DateTime startTime;
  final DateTime? endTime;
  final String container;
  final String playbackUrl;
  final int? fileSize;
  final int? durationMs;
  final String? videoCodec;
  final String? audioCodec;
  final int? width;
  final int? height;
  final double? fps;

  factory Recording.fromJson(Map<String, Object?> json) => Recording(
    id: json['id']! as String,
    cameraId: json['cameraId']! as String,
    startTime: DateTime.parse(json['startTime']! as String),
    endTime: json['endTime'] == null
        ? null
        : DateTime.parse(json['endTime']! as String),
    container: json['container']! as String,
    playbackUrl: json['playbackUrl']! as String,
    fileSize: (json['fileSize'] as num?)?.toInt(),
    durationMs: (json['durationMs'] as num?)?.toInt(),
    videoCodec: json['videoCodec'] as String?,
    audioCodec: json['audioCodec'] as String?,
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
    fps: (json['fps'] as num?)?.toDouble(),
  );
}
