class RecordingTimelineInterval {
  const RecordingTimelineInterval({
    required this.recordingId,
    required this.cameraId,
    required this.startTime,
    required this.endTime,
  });

  final String recordingId;
  final String cameraId;
  final DateTime startTime;
  final DateTime endTime;

  Duration get duration => endTime.difference(startTime);

  factory RecordingTimelineInterval.fromJson(Map<String, Object?> json) =>
      RecordingTimelineInterval(
        recordingId: json['recordingId']! as String,
        cameraId: json['cameraId']! as String,
        startTime: DateTime.parse(json['startTime']! as String),
        endTime: DateTime.parse(json['endTime']! as String),
      );
}
