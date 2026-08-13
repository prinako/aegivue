class Recording {
  const Recording({
    required this.id,
    required this.cameraId,
    required this.startTime,
    required this.container,
    required this.playbackUrl,
  });
  final String id;
  final String cameraId;
  final DateTime startTime;
  final String container;
  final String playbackUrl;
  factory Recording.fromJson(Map<String, Object?> json) => Recording(
    id: json['id']! as String,
    cameraId: json['cameraId']! as String,
    startTime: DateTime.parse(json['startTime']! as String),
    container: json['container']! as String,
    playbackUrl: json['playbackUrl']! as String,
  );
}
